-- Web MVP backendi: OTP, mehmon kabineti, restoran tizimi va admin amallari.
-- Ichki kalitlar Vault'da tasodifiy yaratiladi va faqat service_role o'qiydi.

create extension if not exists supabase_vault with schema vault;
create extension if not exists pg_cron;

select vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'tegio_' || n)
from unnest(array['card_token_secret', 'wifi_encryption_key', 'session_secret', 'otp_pepper']) n
where not exists (select 1 from vault.secrets s where s.name = 'tegio_' || n);

create function public.internal_secret(p_name text) returns text
language sql stable security definer set search_path = '' as $$
  select decrypted_secret from vault.decrypted_secrets where name = 'tegio_' || p_name;
$$;

-- Yangi ustun va jadvallar.
alter table public.businesses add column telegram_chat_id text;
grant update (telegram_chat_id) on public.businesses to authenticated;
alter table public.support_tickets add column body text, add column reply text,
  add column created_by uuid default auth.uid();
alter table public.payments add column plan text references public.plans (id), add column note text;

create table public.otp_codes (
  phone text primary key,
  code_hash text not null,
  attempts integer not null default 0,
  expires_at timestamptz not null
);

create table public.staff_invites (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  location_id uuid,
  phone text not null check (phone ~ '^\+[0-9]{9,15}$'),
  role public.staff_role not null check (role <> 'owner'),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  unique (business_id, phone),
  foreign key (location_id, business_id) references public.locations (id, business_id)
);

create table public.content_reports (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  reason text not null,
  status text not null default 'open' check (status in ('open', 'resolved', 'rejected')),
  created_at timestamptz not null default now()
);

create table public.deletion_requests (
  id uuid primary key default gen_random_uuid(),
  phone text not null,
  status text not null default 'open' check (status in ('open', 'done')),
  created_at timestamptz not null default now(),
  done_at timestamptz
);

create table public.message_templates (
  key text not null,
  channel text not null check (channel in ('sms', 'telegram')),
  locale text not null check (locale in ('uz', 'uz-Cyrl', 'ru', 'en')),
  body text not null,
  primary key (key, channel, locale)
);

create table public.usage_events (
  id bigint generated always as identity primary key,
  business_id uuid references public.businesses (id) on delete cascade,
  kind text not null check (kind in ('sms', 'ai')),
  cost_uzs integer not null default 0,
  created_at timestamptz not null default now()
);
create index usage_events_business_idx on public.usage_events (business_id, created_at desc);

alter table public.otp_codes enable row level security;
alter table public.staff_invites enable row level security;
alter table public.content_reports enable row level security;
alter table public.deletion_requests enable row level security;
alter table public.message_templates enable row level security;
alter table public.usage_events enable row level security;

create policy staff_invites_owner_read on public.staff_invites for select to authenticated
  using (business_id in (select private.staff_business_ids('{owner}')));

-- Yordamchilar.
create function private.require_staff(p_business_id uuid, p_roles public.staff_role[])
returns public.staff_role
language plpgsql stable security definer set search_path = '' as $$
declare v_role public.staff_role;
begin
  select role into v_role from public.staff_members
    where user_id = auth.uid() and business_id = p_business_id and status = 'active' and role = any (p_roles);
  if v_role is null then raise exception 'forbidden' using errcode = '42501'; end if;
  return v_role;
end;
$$;

-- Har bir admin so'rovida rol va 2FA tekshiriladi (P-28, TTZ 8-bo'lim).
create function private.require_admin(p_roles public.admin_role[])
returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare v_id uuid;
begin
  if coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then
    raise exception 'mfa_required' using errcode = '42501';
  end if;
  select id into v_id from public.admin_users
    where user_id = auth.uid() and status = 'active' and role = any (p_roles);
  if v_id is null then raise exception 'forbidden' using errcode = '42501'; end if;
  return v_id;
end;
$$;

create function private.audit(p_action text, p_entity text, p_before jsonb, p_after jsonb) returns void
language sql security definer set search_path = '' as $$
  insert into public.audit_log (actor_id, action, entity, before, after)
  values (auth.uid(), p_action, p_entity, p_before, p_after);
$$;

grant execute on function private.require_staff(uuid, public.staff_role[]) to authenticated;
grant execute on function private.require_admin(public.admin_role[]) to authenticated;

-- OTP: kod xeshlanadi, 5 daqiqa, 5 urinish, soatiga 5 SMS (TTZ: suiiste'mol limitlari).
create function public.otp_issue(p_phone text, p_code text) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.check_rate_limit('otp:' || p_phone, 3600, 5) then return false; end if;
  insert into public.otp_codes as o (phone, code_hash, attempts, expires_at)
  values (p_phone, encode(extensions.digest(p_code || public.internal_secret('otp_pepper'), 'sha256'), 'hex'),
          0, now() + interval '5 minutes')
  on conflict (phone) do update
    set code_hash = excluded.code_hash, attempts = 0, expires_at = excluded.expires_at;
  return true;
end;
$$;

create function public.otp_verify(p_phone text, p_code text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare v public.otp_codes;
begin
  select * into v from public.otp_codes where phone = p_phone for update;
  if not found or v.expires_at < now() or v.attempts >= 5 then return false; end if;
  if v.code_hash <> encode(extensions.digest(p_code || public.internal_secret('otp_pepper'), 'sha256'), 'hex') then
    update public.otp_codes set attempts = attempts + 1 where phone = p_phone;
    return false;
  end if;
  delete from public.otp_codes where phone = p_phone;
  return true;
end;
$$;

-- Mehmon kabineti (U-01 – U-06).
create function public.ensure_guest(p_user_id uuid, p_phone text) returns void
language sql security definer set search_path = '' as $$
  insert into public.guests (user_id, phone) values (p_user_id, p_phone) on conflict (user_id) do nothing;
$$;

create function public.guest_profile(p_user_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('name', coalesce(name, ''), 'phone', phone, 'locale', coalesce(locale, 'uz'))
  from public.guests where user_id = p_user_id;
$$;

create function public.guest_update_profile(p_user_id uuid, p_name text, p_locale text) returns void
language sql security definer set search_path = '' as $$
  update public.guests set name = nullif(p_name, ''), locale = p_locale where user_id = p_user_id;
$$;

create function private.card_json(p_m public.memberships) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'membership_id', p_m.id, 'marketing_consent', p_m.marketing_consent,
    'business_name', b.name, 'slug', b.slug, 'stamps', p_m.stamps,
    'tiers', coalesce((select jsonb_agg(jsonb_build_object('stamps_required', t.stamps_required, 'title', t.title)
                       order by t.stamps_required) from public.reward_tiers t where t.program_id = p_m.program_id), '[]'::jsonb),
    'rewards', (select coalesce(jsonb_agg(jsonb_build_object('id', e ->> 'id', 'title', e ->> 'title', 'expires_at', e ->> 'expires_at')), '[]'::jsonb)
                from jsonb_array_elements(private.result_rewards(p_m.id)) e))
  from public.businesses b where b.id = p_m.business_id;
$$;

create function public.guest_card(p_user_id uuid, p_slug text) returns jsonb
language sql stable security definer set search_path = '' as $$
  select private.card_json(m)
  from public.memberships m
  join public.guests g on g.id = m.guest_id
  join public.businesses b on b.id = m.business_id
  where g.user_id = p_user_id and b.slug = p_slug and m.status = 'active';
$$;

create function public.guest_cards(p_user_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(private.card_json(m)), '[]'::jsonb)
  from public.memberships m join public.guests g on g.id = m.guest_id
  where g.user_id = p_user_id and m.status = 'active';
$$;

create function public.guest_visits(p_user_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(v order by v ->> 'at' desc), '[]'::jsonb) from (
    select jsonb_build_object('at', e.created_at, 'kind', e.reason, 'business_name', b.name) v
    from public.stamp_events e
    join public.memberships m on m.id = e.membership_id
    join public.guests g on g.id = m.guest_id
    join public.businesses b on b.id = m.business_id
    where g.user_id = p_user_id and e.reason in ('stamp', 'redeem')
    order by e.created_at desc limit 100) s;
$$;

create function public.guest_set_marketing(p_user_id uuid, p_membership_id uuid, p_consent boolean) returns void
language sql security definer set search_path = '' as $$
  update public.memberships m
    set marketing_consent = p_consent, consent_at = case when p_consent then now() end
    from public.guests g
    where m.id = p_membership_id and g.id = m.guest_id and g.user_id = p_user_id;
$$;

create function public.guest_membership_for_token(p_user_id uuid, p_slug text) returns uuid
language sql stable security definer set search_path = '' as $$
  select m.id from public.memberships m
  join public.guests g on g.id = m.guest_id
  join public.businesses b on b.id = m.business_id
  where g.user_id = p_user_id and b.slug = p_slug and m.status = 'active';
$$;

-- Skan, fikr, demo (G-06, F-01, F-02, S-03).
create function public.log_scan(p_slug text, p_action text, p_tag_code text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_b uuid; v_tag public.tags; v_loc uuid;
begin
  select id into v_b from public.businesses where slug = p_slug;
  if not found then return; end if;
  if p_tag_code is not null then
    select * into v_tag from public.tags where code = p_tag_code and business_id = v_b;
  end if;
  v_loc := v_tag.location_id;
  if v_loc is null then
    select id into v_loc from public.locations where business_id = v_b order by created_at limit 1;
  end if;
  if v_loc is null then return; end if;
  insert into public.scan_events (business_id, tag_id, location_id, action)
    values (v_b, v_tag.id, v_loc, left(p_action, 40));
end;
$$;

create function public.submit_feedback(
  p_slug text, p_device text, p_rating integer, p_text text, p_contact text, p_tag_code text
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_b public.businesses; v_tag public.tags; v_loc uuid;
begin
  select * into v_b from public.businesses where slug = p_slug and status = 'active';
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not public.check_rate_limit('fb:' || p_slug || ':' || p_device, 600, 1) then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  if p_tag_code is not null then
    select * into v_tag from public.tags where code = p_tag_code and business_id = v_b.id;
  end if;
  v_loc := v_tag.location_id;
  if v_loc is null then
    select id into v_loc from public.locations where business_id = v_b.id order by created_at limit 1;
  end if;
  insert into public.feedback (business_id, location_id, tag_id, rating, text, contact)
    values (v_b.id, v_loc, v_tag.id, p_rating, left(p_text, 2000), left(p_contact, 200));
  return jsonb_build_object('ok', true, 'telegram_chat_id', v_b.telegram_chat_id, 'business_name', v_b.name);
end;
$$;

-- Sinov paytida Start imkoniyatlari ochiq bo'ladi; biznesni faqat tasdiqlangan telefon ochadi.
create or replace function public.create_business(p_name text, p_slug text, p_location_name text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_business_id uuid;
begin
  if v_user is null or not exists (
    select 1 from auth.users where id = v_user and phone_confirmed_at is not null
  ) then
    raise exception 'auth required' using errcode = '42501';
  end if;
  insert into public.businesses (name, slug, owner_id, plan)
    values (p_name, p_slug, v_user, 'start') returning id into v_business_id;
  insert into public.staff_members (business_id, user_id, role)
    values (v_business_id, v_user, 'owner');
  insert into public.locations (business_id, name) values (v_business_id, p_location_name);
  insert into public.loyalty_programs (business_id) values (v_business_id);
  insert into public.subscriptions (business_id, plan, status, period_end)
    values (v_business_id, 'start', 'trial', now() + interval '30 days');
  return v_business_id;
end;
$$;

-- Restoran tizimi.
create function public.my_businesses() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', b.id, 'name', b.name, 'slug', b.slug, 'role', s.role, 'plan', b.plan, 'status', b.status,
    'brand', b.brand_json, 'telegram_chat_id', case when s.role = 'owner' then b.telegram_chat_id end,
    'staff_location_id', s.location_id,
    'locations', (select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name, 'address', l.address,
       'wifi_ssid', l.wifi_ssid, 'google_review_url', l.google_review_url) order by l.created_at), '[]'::jsonb)
       from public.locations l where l.business_id = b.id and (s.location_id is null or l.id = s.location_id))
  ) order by b.created_at), '[]'::jsonb)
  from public.staff_members s join public.businesses b on b.id = s.business_id
  where s.user_id = auth.uid() and s.status = 'active';
$$;

create function public.invite_staff(p_business_id uuid, p_phone text, p_role public.staff_role, p_location_id uuid)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_staff(p_business_id, '{owner}');
  if p_role = 'owner' then raise exception 'forbidden' using errcode = '42501'; end if;
  insert into public.staff_invites (business_id, phone, role, location_id)
  values (p_business_id, p_phone, p_role, p_location_id)
  on conflict (business_id, phone) do update
    set role = excluded.role, location_id = excluded.location_id, accepted_at = null;
end;
$$;

-- Kirgandan keyin chaqiriladi: telefon faqat tasdiqlangan auth.users qatoridan olinadi (B-03).
create function public.claim_staff_invites() returns integer
language plpgsql security definer set search_path = '' as $$
declare v_phone text; v_count integer := 0; v_i public.staff_invites;
begin
  select '+' || ltrim(phone, '+') into v_phone from auth.users
    where id = auth.uid() and phone_confirmed_at is not null;
  if v_phone is null then return 0; end if;
  for v_i in select * from public.staff_invites where phone = v_phone and accepted_at is null loop
    insert into public.staff_members (business_id, location_id, user_id, role)
    values (v_i.business_id, v_i.location_id, auth.uid(), v_i.role)
    on conflict (business_id, user_id) do update
      set role = excluded.role, location_id = excluded.location_id, status = 'active';
    update public.staff_invites set accepted_at = now() where id = v_i.id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create function public.remove_staff(p_business_id uuid, p_staff_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_staff(p_business_id, '{owner}');
  update public.staff_members set status = 'removed'
    where id = p_staff_id and business_id = p_business_id and role <> 'owner';
end;
$$;

create function public.team_list(p_business_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_staff(p_business_id, '{owner,manager}');
  return jsonb_build_object(
    'members', (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'role', s.role, 'location_id', s.location_id,
       'phone', private.mask_phone('+' || ltrim(u.phone, '+'))) order by s.created_at), '[]'::jsonb)
       from public.staff_members s join auth.users u on u.id = s.user_id
       where s.business_id = p_business_id and s.status = 'active'),
    'invites', (select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'role', i.role, 'phone', private.mask_phone(i.phone))), '[]'::jsonb)
       from public.staff_invites i where i.business_id = p_business_id and i.accepted_at is null));
end;
$$;

-- Stol yorliqlari (B-08): takrorlanmas kod bazada yaratiladi.
create function public.create_table_tags(p_business_id uuid, p_location_id uuid, p_labels text[], p_type public.tag_type)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_label text; v_out jsonb := '[]'::jsonb; v_code text;
begin
  perform private.require_staff(p_business_id, '{owner,manager}');
  if coalesce(array_length(p_labels, 1), 0) > 100 then raise exception 'too_many'; end if;
  foreach v_label in array p_labels loop
    v_code := upper(encode(extensions.gen_random_bytes(5), 'hex'));
    insert into public.tags (code, business_id, location_id, table_label, type)
      values (v_code, p_business_id, p_location_id, v_label, p_type);
    v_out := v_out || jsonb_build_object('code', v_code, 'table_label', v_label);
  end loop;
  return v_out;
end;
$$;

-- Boshqaruv ekrani va taqqoslash (B-34, B-36). Google sharh ko'rsatkichi yo'q (F-05).
create function public.business_stats(p_business_id uuid, p_days integer) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_from timestamptz := now() - make_interval(days => p_days);
begin
  perform private.require_staff(p_business_id, '{owner,manager}');
  return jsonb_build_object(
    'scans', (select count(*) from public.scan_events where business_id = p_business_id and created_at >= v_from and action = 'open'),
    'new_members', (select count(*) from public.memberships where business_id = p_business_id and created_at >= v_from),
    'members', (select count(*) from public.memberships where business_id = p_business_id and status = 'active'),
    'returning', (select count(*) from (select membership_id from public.stamp_events
        where business_id = p_business_id and reason = 'stamp' and created_at >= v_from
        group by membership_id having count(*) > 1) r),
    'rewards_redeemed', (select count(*) from public.rewards where business_id = p_business_id and redeemed_at >= v_from),
    'avg_rating', (select round(avg(rating), 2) from public.feedback where business_id = p_business_id and created_at >= v_from),
    'by_location', (select coalesce(jsonb_agg(jsonb_build_object('name', l.name,
        'scans', (select count(*) from public.scan_events e where e.location_id = l.id and e.created_at >= v_from),
        'stamps', (select count(*) from public.stamp_events e where e.location_id = l.id and e.reason = 'stamp' and e.created_at >= v_from))), '[]'::jsonb)
        from public.locations l where l.business_id = p_business_id),
    'by_table', (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
        select jsonb_build_object('name', t.table_label, 'scans', count(*)) x from public.scan_events e
        join public.tags t on t.id = e.tag_id
        where e.business_id = p_business_id and e.created_at >= v_from
        group by t.table_label order by count(*) desc limit 50) a),
    'by_staff', (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
        select jsonb_build_object('staff_id', e.staff_id, 'role', s.role,
          'phone', private.mask_phone('+' || ltrim(u.phone, '+')), 'stamps', count(*)) x
        from public.stamp_events e
        join public.staff_members s on s.id = e.staff_id
        join auth.users u on u.id = s.user_id
        where e.business_id = p_business_id and e.reason = 'stamp' and e.created_at >= v_from
        group by e.staff_id, s.role, u.phone order by count(*) desc) b));
end;
$$;

-- Obuna (B-39 – B-41).
create function public.subscription_state(p_business_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_staff(p_business_id, '{owner}');
  return jsonb_build_object(
    'subscription', (select to_jsonb(s) from public.subscriptions s where business_id = p_business_id order by period_end desc limit 1),
    'plans', (select jsonb_agg(to_jsonb(p) order by p.price_uzs) from public.plans p),
    'payments', (select coalesce(jsonb_agg(to_jsonb(p) order by p.created_at desc), '[]'::jsonb) from public.payments p where business_id = p_business_id));
end;
$$;

create function public.create_payment(p_user_id uuid, p_business_id uuid, p_plan text, p_provider text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_price integer; v_id uuid;
begin
  if not exists (select 1 from public.staff_members where user_id = p_user_id and business_id = p_business_id and role = 'owner' and status = 'active') then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  select price_uzs into v_price from public.plans where id = p_plan and price_uzs > 0;
  if v_price is null then return jsonb_build_object('ok', false, 'error', 'bad_plan'); end if;
  insert into public.payments (business_id, amount_uzs, provider, status, plan)
    values (p_business_id, v_price, p_provider, 'pending', p_plan) returning id into v_id;
  return jsonb_build_object('ok', true, 'payment_id', v_id, 'amount_uzs', v_price);
end;
$$;

-- Takroriy webhook obunani ikki marta uzaytirmaydi.
create function public.complete_payment(p_payment_id uuid, p_provider_txn text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare v public.payments; v_end timestamptz;
begin
  select * into v from public.payments where id = p_payment_id for update;
  if not found then return false; end if;
  if v.status = 'paid' then return true; end if;
  update public.payments set status = 'paid', paid_at = now(), provider_txn_id = coalesce(p_provider_txn, provider_txn_id) where id = v.id;
  select greatest(max(period_end), now()) into v_end from public.subscriptions where business_id = v.business_id;
  delete from public.subscriptions where business_id = v.business_id;
  insert into public.subscriptions (business_id, plan, status, period_end, provider)
    values (v.business_id, v.plan, 'active', coalesce(v_end, now()) + interval '1 month', v.provider);
  update public.businesses set plan = v.plan,
    status = case when status = 'payment_stopped' then 'active'::public.business_status else status end
    where id = v.business_id;
  return true;
end;
$$;

create function public.get_payment(p_payment_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select to_jsonb(p) from public.payments p where id = p_payment_id;
$$;

-- Admin panel (P-01 – P-30). Har biri rol va 2FA'ni tekshiradi, yozuvlar jurnalga tushadi.
create function public.admin_me() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', id, 'email', email, 'role', role, 'status', status)
  from public.admin_users where user_id = auth.uid() and status = 'active';
$$;

create function public.admin_activate() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then raise exception 'mfa_required' using errcode = '42501'; end if;
  update public.admin_users set status = 'active', totp_enabled = true
    where user_id = auth.uid() and status = 'invited';
end;
$$;

create function public.admin_dashboard() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin('{super_admin,support,finance}');
  return jsonb_build_object(
    'active', (select count(*) from public.businesses where status = 'active'),
    'new_30d', (select count(*) from public.businesses where created_at > now() - interval '30 days'),
    'trial', (select count(*) from public.subscriptions where status = 'trial' and period_end > now()),
    'churned', (select count(*) from public.subscriptions where status in ('cancelled', 'past_due')),
    'mrr_uzs', (select coalesce(sum(p.price_uzs), 0) from public.subscriptions s join public.plans p on p.id = s.plan where s.status = 'active'),
    'paid_this_month', (select coalesce(sum(amount_uzs), 0) from public.payments where status = 'paid' and paid_at >= date_trunc('month', now())),
    'overdue', (select count(*) from public.subscriptions where period_end < now() and status <> 'cancelled'),
    'daily', (select coalesce(jsonb_agg(d order by d ->> 'day'), '[]'::jsonb) from (
      select jsonb_build_object('day', g::date,
        'scans', (select count(*) from public.scan_events e where e.created_at::date = g::date and e.action = 'open'),
        'members', (select count(*) from public.memberships e where e.created_at::date = g::date),
        'stamps', (select count(*) from public.stamp_events e where e.created_at::date = g::date and e.reason = 'stamp'),
        'feedback', (select count(*) from public.feedback e where e.created_at::date = g::date)) d
      from generate_series(now() - interval '13 days', now(), interval '1 day') g) x));
end;
$$;

create function public.admin_businesses(p_q text, p_city text, p_plan text, p_status text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin('{super_admin,support,finance}');
  return (select coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'name', b.name, 'slug', b.slug, 'city', b.city,
      'plan', b.plan, 'status', b.status, 'created_at', b.created_at) order by b.created_at desc), '[]'::jsonb)
    from public.businesses b
    where (p_q is null or b.name ilike '%' || p_q || '%' or b.slug ilike '%' || p_q || '%')
      and (p_city is null or b.city = p_city) and (p_plan is null or b.plan = p_plan)
      and (p_status is null or b.status::text = p_status));
end;
$$;

-- Har bir ko'rish jurnalga yoziladi (P-08); mehmon telefonlari yashirin (P-09).
create function public.admin_business(p_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin('{super_admin,support,finance}');
  perform private.audit('business.view', 'business:' || p_id, null, null);
  return (select jsonb_build_object(
    'business', jsonb_build_object('id', b.id, 'name', b.name, 'slug', b.slug, 'city', b.city, 'plan', b.plan, 'status', b.status, 'status_reason', b.status_reason),
    'locations', (select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name, 'address', l.address)), '[]'::jsonb) from public.locations l where l.business_id = b.id),
    'team', (select coalesce(jsonb_agg(jsonb_build_object('role', s.role, 'status', s.status)), '[]'::jsonb) from public.staff_members s where s.business_id = b.id),
    'members', (select count(*) from public.memberships m where m.business_id = b.id and m.status = 'active'),
    'customers', (select coalesce(jsonb_agg(jsonb_build_object('name', g.name, 'phone', private.mask_phone(g.phone))), '[]'::jsonb)
       from (select g.* from public.memberships m join public.guests g on g.id = m.guest_id where m.business_id = b.id limit 50) g),
    'payments', (select coalesce(jsonb_agg(to_jsonb(p) order by p.created_at desc), '[]'::jsonb) from public.payments p where p.business_id = b.id),
    'subscription', (select to_jsonb(s) from public.subscriptions s where s.business_id = b.id order by period_end desc limit 1))
    from public.businesses b where b.id = p_id);
end;
$$;

create function public.admin_set_business_status(p_id uuid, p_status public.business_status, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_old jsonb;
begin
  perform private.require_admin('{super_admin,support}');
  select jsonb_build_object('status', status, 'reason', status_reason) into v_old from public.businesses where id = p_id;
  update public.businesses set status = p_status, status_reason = p_reason where id = p_id;
  perform private.audit('business.status', 'business:' || p_id, v_old, jsonb_build_object('status', p_status, 'reason', p_reason));
end;
$$;

create function public.admin_set_plan(p_id uuid, p_plan text, p_days integer) returns void
language plpgsql security definer set search_path = '' as $$
declare v_old text;
begin
  perform private.require_admin('{super_admin,finance}');
  select plan into v_old from public.businesses where id = p_id;
  update public.businesses set plan = p_plan where id = p_id;
  delete from public.subscriptions where business_id = p_id;
  insert into public.subscriptions (business_id, plan, status, period_end, provider)
    values (p_id, p_plan, 'active', now() + make_interval(days => p_days), 'manual');
  perform private.audit('business.plan', 'business:' || p_id, to_jsonb(v_old), jsonb_build_object('plan', p_plan, 'days', p_days));
end;
$$;

create function public.admin_extend_trial(p_id uuid, p_days integer) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin('{super_admin,finance}');
  update public.subscriptions set period_end = greatest(period_end, now()) + make_interval(days => p_days), status = 'trial'
    where business_id = p_id;
  perform private.audit('business.extend_trial', 'business:' || p_id, null, to_jsonb(p_days));
end;
$$;

create function public.admin_add_payment(p_id uuid, p_plan text, p_amount integer, p_provider text, p_note text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_pay uuid;
begin
  perform private.require_admin('{super_admin,finance}');
  if p_provider not in ('cash', 'bank') then raise exception 'bad_provider'; end if;
  insert into public.payments (business_id, amount_uzs, provider, status, plan, note)
    values (p_id, p_amount, p_provider, 'pending', p_plan, p_note) returning id into v_pay;
  perform public.complete_payment(v_pay, null);
  perform private.audit('payment.manual', 'payment:' || v_pay, null, jsonb_build_object('amount', p_amount, 'provider', p_provider));
end;
$$;

create function public.admin_payments() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin('{super_admin,finance}');
  return (select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb) from
    (select p.*, b.name business_name from public.payments p join public.businesses b on b.id = p.business_id order by p.created_at desc limit 300) x);
end;
$$;

create function public.admin_save_plan(p_id text, p_name text, p_price integer, p_limits jsonb, p_modules jsonb) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin('{super_admin,finance}');
  insert into public.plans (id, name, price_uzs, limits_json, modules_json) values (p_id, p_name, p_price, p_limits, p_modules)
  on conflict (id) do update set name = excluded.name, price_uzs = excluded.price_uzs, limits_json = excluded.limits_json, modules_json = excluded.modules_json;
  perform private.audit('plan.save', 'plan:' || p_id, null, jsonb_build_object('name', p_name, 'price', p_price));
end;
$$;

create function public.admin_list(p_kind text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v jsonb;
begin
  perform private.require_admin(case
    when p_kind in ('audit', 'admins') then '{super_admin}'::public.admin_role[]
    else '{super_admin,support,finance}'::public.admin_role[] end);
  case p_kind
    when 'demo' then select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb) into v from public.demo_requests x;
    when 'tickets' then select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb) into v from public.support_tickets x;
    when 'reports' then select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb) into v from public.content_reports x;
    when 'deletions' then select coalesce(jsonb_agg(to_jsonb(x) || jsonb_build_object('phone', private.mask_phone(x.phone)) order by x.created_at desc), '[]'::jsonb) into v from public.deletion_requests x;
    when 'tags' then select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v from (select * from public.tags order by created_at desc limit 500) x;
    when 'batches' then select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb) into v from public.tag_batches x;
    when 'content' then select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v from public.site_content x;
    when 'flags' then select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v from public.feature_flags x;
    when 'templates' then select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v from public.message_templates x;
    when 'plans' then select coalesce(jsonb_agg(to_jsonb(x) order by x.price_uzs), '[]'::jsonb) into v from public.plans x;
    when 'usage' then select coalesce(jsonb_agg(x), '[]'::jsonb) into v from (
      select jsonb_build_object('business', b.name, 'kind', u.kind, 'count', count(*), 'cost_uzs', sum(u.cost_uzs)) x
      from public.usage_events u left join public.businesses b on b.id = u.business_id
      where u.created_at >= date_trunc('month', now()) group by b.name, u.kind) a;
    when 'audit' then select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v from (select * from public.audit_log order by created_at desc limit 300) x;
    when 'admins' then select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v from public.admin_users x;
    else raise exception 'bad_kind';
  end case;
  return v;
end;
$$;

create function public.admin_update_demo(p_id uuid, p_status text, p_note text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_admin uuid;
begin
  v_admin := private.require_admin('{super_admin,support}');
  update public.demo_requests set status = p_status, note = p_note, assignee_id = v_admin where id = p_id;
  perform private.audit('demo.update', 'demo:' || p_id, null, jsonb_build_object('status', p_status));
end;
$$;

create function public.admin_update_ticket(p_id uuid, p_status text, p_reply text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_admin uuid;
begin
  v_admin := private.require_admin('{super_admin,support}');
  update public.support_tickets set status = p_status, reply = p_reply, assignee_id = v_admin where id = p_id;
  perform private.audit('ticket.update', 'ticket:' || p_id, null, jsonb_build_object('status', p_status));
end;
$$;

create function public.admin_resolve_report(p_id uuid, p_status text, p_hide boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare v_b uuid;
begin
  perform private.require_admin('{super_admin,support}');
  update public.content_reports set status = p_status where id = p_id returning business_id into v_b;
  if p_hide then update public.businesses set status = 'hidden', status_reason = 'content' where id = v_b; end if;
  perform private.audit('report.resolve', 'report:' || p_id, null, jsonb_build_object('status', p_status, 'hide', p_hide));
end;
$$;

create function public.admin_complete_deletion(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_phone text; v_user uuid;
begin
  perform private.require_admin('{super_admin,support}');
  select phone into v_phone from public.deletion_requests where id = p_id;
  select user_id into v_user from public.guests where phone = v_phone;
  if v_user is not null then perform public.delete_guest(v_user); end if;
  update public.deletion_requests set status = 'done', done_at = now() where id = p_id;
  perform private.audit('guest.delete', 'deletion:' || p_id, null, null);
end;
$$;

create function public.admin_create_batch(p_type public.tag_type, p_quantity integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_batch uuid; v_out jsonb := '[]'::jsonb; v_code text;
begin
  perform private.require_admin('{super_admin}');
  if p_quantity not between 1 and 2000 then raise exception 'bad_quantity'; end if;
  insert into public.tag_batches (type, quantity, created_by) values (p_type, p_quantity, auth.uid()) returning id into v_batch;
  for i in 1..p_quantity loop
    v_code := upper(encode(extensions.gen_random_bytes(5), 'hex'));
    insert into public.tags (code, type, batch_id) values (v_code, p_type, v_batch);
    v_out := v_out || to_jsonb(v_code);
  end loop;
  perform private.audit('batch.create', 'batch:' || v_batch, null, jsonb_build_object('quantity', p_quantity));
  return v_out;
end;
$$;

create function public.admin_assign_tag(p_code text, p_business uuid, p_location uuid, p_label text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_old jsonb;
begin
  perform private.require_admin('{super_admin,support}');
  select jsonb_build_object('business_id', business_id, 'location_id', location_id) into v_old from public.tags where code = p_code;
  if v_old is null then raise exception 'tag_not_found'; end if;
  update public.tags set business_id = p_business, location_id = p_location, table_label = p_label where code = p_code;
  perform private.audit('tag.assign', 'tag:' || p_code, v_old, jsonb_build_object('business_id', p_business, 'location_id', p_location));
end;
$$;

create function public.admin_save_content(p_key text, p_locale text, p_value text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin('{super_admin}');
  insert into public.site_content (key, locale, value, updated_by) values (p_key, p_locale, p_value, auth.uid())
  on conflict (key, locale) do update set value = excluded.value, updated_by = excluded.updated_by;
  perform private.audit('content.save', 'content:' || p_key || ':' || p_locale, null, null);
end;
$$;

create function public.admin_save_template(p_key text, p_channel text, p_locale text, p_body text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin('{super_admin}');
  insert into public.message_templates (key, channel, locale, body) values (p_key, p_channel, p_locale, p_body)
  on conflict (key, channel, locale) do update set body = excluded.body;
  perform private.audit('template.save', 'template:' || p_key, null, null);
end;
$$;

create function public.admin_set_flag(p_key text, p_business uuid, p_enabled boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin('{super_admin}');
  insert into public.feature_flags (key, scope, business_id, enabled)
  values (p_key, case when p_business is null then 'global' else 'business' end, p_business, p_enabled)
  on conflict (key, business_id) do update set enabled = excluded.enabled;
  perform private.audit('flag.set', 'flag:' || p_key, null, jsonb_build_object('business', p_business, 'enabled', p_enabled));
end;
$$;

-- Faqat taklif (P-27): ro'yxatga oluvchi Edge Function, rolni shu yerda tekshiradi.
create function public.admin_invite_record(p_actor uuid, p_user_id uuid, p_email text, p_role public.admin_role) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.admin_users where user_id = p_actor and status = 'active' and role = 'super_admin') then
    return false;
  end if;
  insert into public.admin_users (user_id, email, role, status) values (p_user_id, p_email, p_role, 'invited');
  insert into public.audit_log (actor_id, action, entity, after)
    values (p_actor, 'admin.invite', 'admin:' || p_email, jsonb_build_object('role', p_role));
  return true;
end;
$$;

create function public.is_super_admin(p_user_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admin_users where user_id = p_user_id and status = 'active' and role = 'super_admin');
$$;

-- Har kungi tozalash: eskirgan cheklovlar, tokenlar, mukofotlar va obunalar.
create function private.daily_maintenance() returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.rate_limits where window_start < now() - interval '2 days';
  delete from public.used_card_tokens where used_at < now() - interval '2 days';
  delete from public.otp_codes where expires_at < now() - interval '1 day';
  update public.rewards set status = 'expired' where status = 'available' and expires_at <= now();
  update public.subscriptions set status = 'past_due' where status = 'active' and period_end < now();
  update public.businesses b set plan = 'free' from public.subscriptions s
    where s.business_id = b.id and s.status = 'trial' and s.period_end < now() and b.plan <> 'free';
  update public.subscriptions set status = 'cancelled' where status = 'trial' and period_end < now();
  update public.businesses b set status = 'payment_stopped' from public.subscriptions s
    where s.business_id = b.id and s.status = 'past_due' and s.period_end < now() - interval '7 days' and b.status = 'active';
end;
$$;

select cron.schedule('tegio-daily', '5 19 * * *', 'select private.daily_maintenance()');

-- Taom rasmi, logotip va muqova uchun ochiq bucket: yo'l biznes id'si bilan boshlanadi.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy media_read on storage.objects for select to anon, authenticated using (bucket_id = 'media');
create policy media_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and (storage.foldername(name))[1]::uuid in (select private.staff_business_ids('{owner,manager}')));
create policy media_update on storage.objects for update to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1]::uuid in (select private.staff_business_ids('{owner,manager}')));
create policy media_delete on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1]::uuid in (select private.staff_business_ids('{owner,manager}')));

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
    public.internal_secret(text), public.check_rate_limit(text, integer, integer),
    public.apply_stamp(uuid, uuid, uuid, text, text), public.redeem_reward(uuid, uuid, uuid),
    public.find_member_by_phone(uuid, uuid, text),
    public.join_program(uuid, text, text, text, boolean, boolean),
    public.leave_program(uuid, uuid), public.delete_guest(uuid),
    public.set_location_wifi(uuid, text, text, text), public.public_page(text, text, text),
    public.otp_issue(text, text), public.otp_verify(text, text), public.ensure_guest(uuid, text),
    public.guest_profile(uuid), public.guest_update_profile(uuid, text, text),
    public.guest_card(uuid, text), public.guest_cards(uuid), public.guest_visits(uuid),
    public.guest_set_marketing(uuid, uuid, boolean), public.guest_membership_for_token(uuid, text),
    public.log_scan(text, text, text), public.submit_feedback(text, text, integer, text, text, text),
    public.create_payment(uuid, uuid, text, text), public.complete_payment(uuid, text),
    public.get_payment(uuid), public.admin_invite_record(uuid, uuid, text, public.admin_role),
    public.is_super_admin(uuid)
  to service_role;

grant execute on function
    public.create_business(text, text, text), public.business_customers(uuid), public.my_businesses(),
    public.invite_staff(uuid, text, public.staff_role, uuid), public.claim_staff_invites(),
    public.remove_staff(uuid, uuid), public.team_list(uuid),
    public.create_table_tags(uuid, uuid, text[], public.tag_type), public.business_stats(uuid, integer),
    public.subscription_state(uuid), public.admin_me(), public.admin_activate(), public.admin_dashboard(),
    public.admin_businesses(text, text, text, text), public.admin_business(uuid),
    public.admin_set_business_status(uuid, public.business_status, text),
    public.admin_set_plan(uuid, text, integer), public.admin_extend_trial(uuid, integer),
    public.admin_add_payment(uuid, text, integer, text, text), public.admin_payments(),
    public.admin_save_plan(text, text, integer, jsonb, jsonb), public.admin_list(text),
    public.admin_update_demo(uuid, text, text), public.admin_update_ticket(uuid, text, text),
    public.admin_resolve_report(uuid, text, boolean), public.admin_complete_deletion(uuid),
    public.admin_create_batch(public.tag_type, integer), public.admin_assign_tag(text, uuid, uuid, text),
    public.admin_save_content(text, text, text), public.admin_save_template(text, text, text, text),
    public.admin_set_flag(text, uuid, boolean)
  to authenticated;

-- private funksiyalarini faqat RLS siyosatlari chaqiradi.
revoke execute on all functions in schema private from public, anon, authenticated;
grant execute on function private.staff_business_ids(public.staff_role[]) to authenticated;
grant execute on function private.guest_membership_ids() to authenticated;
