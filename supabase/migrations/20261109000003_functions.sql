-- Biznes mantiq. p_user_id oladigan funksiyalar faqat service_role uchun:
-- ularni JWT'ni tekshirgan Edge Function chaqiradi.

create function public.check_rate_limit(p_key text, p_window_seconds integer, p_max integer)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_window timestamptz := to_timestamp(
    floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds);
  v_count integer;
begin
  insert into public.rate_limits as r (key, window_start, count)
  values (p_key, v_window, 1)
  on conflict (key, window_start) do update set count = r.count + 1
  returning count into v_count;
  return v_count <= p_max;
end;
$$;

create function private.mask_phone(p_phone text) returns text
language sql immutable set search_path = '' as $$
  select case when p_phone is null then null
    else left(p_phone, 4) || repeat('*', greatest(length(p_phone) - 6, 0)) || right(p_phone, 2) end;
$$;

-- Muddati o'tgan shtamplarni jurnal orqali nolga tushiradi (B-19).
-- Chaqiruvchi membership qatorini qulflagan bo'lishi kerak.
create function private.lapse_stamps(
  p_membership public.memberships, p_program public.loyalty_programs,
  p_location_id uuid, p_staff_id uuid
) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_last timestamptz;
begin
  if p_program.stamp_expiry_days is null or p_membership.stamps = 0 then
    return p_membership.stamps;
  end if;
  select max(created_at) into v_last from public.stamp_events
    where membership_id = p_membership.id and reason = 'stamp';
  if v_last is null or v_last + make_interval(days => p_program.stamp_expiry_days) > now() then
    return p_membership.stamps;
  end if;
  insert into public.stamp_events
    (business_id, membership_id, location_id, staff_id, delta, reason, idempotency_key)
  values (p_membership.business_id, p_membership.id, p_location_id, p_staff_id,
          -p_membership.stamps, 'expiry', 'expiry:' || gen_random_uuid());
  update public.memberships set stamps = 0 where id = p_membership.id;
  return 0;
end;
$$;

create function private.result_rewards(p_membership_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', r.id, 'title', t.title, 'stamps_required', t.stamps_required, 'expires_at', r.expires_at
  ) order by r.earned_at), '[]'::jsonb)
  from public.rewards r
  join public.reward_tiers t on t.id = r.tier_id
  where r.membership_id = p_membership_id and r.status = 'available'
    and (r.expires_at is null or r.expires_at > now());
$$;

-- Bitta shtamp: tekshiruv, jurnal, hisob va mukofotlar bitta tranzaksiyada.
-- Xatoliklar B-25 bo'yicha aniq kod bilan qaytadi.
create function public.apply_stamp(
  p_user_id uuid, p_membership_id uuid, p_location_id uuid,
  p_jti text, p_idempotency_key text
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_m public.memberships;
  v_p public.loyalty_programs;
  v_staff_id uuid;
  v_prior public.stamp_events;
  v_last timestamptz;
  v_stamps integer;
  v_top integer;
  v_tier public.reward_tiers;
  v_new_rewards jsonb := '[]'::jsonb;
begin
  select * into v_m from public.memberships where id = p_membership_id for update;
  if not found or v_m.status <> 'active' then
    return jsonb_build_object('ok', false, 'error', 'card_not_found');
  end if;

  select id into v_staff_id from public.staff_members
    where user_id = p_user_id and business_id = v_m.business_id and status = 'active'
      and (location_id is null or location_id = p_location_id);
  if v_staff_id is null then
    return jsonb_build_object('ok', false, 'error', 'wrong_business');
  end if;
  if not exists (select 1 from public.locations
                 where id = p_location_id and business_id = v_m.business_id) then
    return jsonb_build_object('ok', false, 'error', 'wrong_business');
  end if;

  -- Ikki marta bosish: birinchi natija qaytadi, yangi shtamp yo'q (B-29).
  select * into v_prior from public.stamp_events where idempotency_key = p_idempotency_key;
  if found then
    if v_prior.membership_id <> p_membership_id then
      return jsonb_build_object('ok', false, 'error', 'idempotency_conflict');
    end if;
    return jsonb_build_object('ok', true, 'duplicate', true, 'stamps', v_m.stamps,
      'new_rewards', '[]'::jsonb, 'available_rewards', private.result_rewards(v_m.id));
  end if;

  if exists (select 1 from public.used_card_tokens where jti = p_jti) then
    return jsonb_build_object('ok', false, 'error', 'qr_used');
  end if;

  select * into v_p from public.loyalty_programs where id = v_m.program_id;
  if not v_p.enabled then
    return jsonb_build_object('ok', false, 'error', 'program_disabled');
  end if;

  select max(created_at) into v_last from public.stamp_events
    where membership_id = v_m.id and reason = 'stamp';
  if v_last is not null and v_last + make_interval(mins => v_p.stamp_interval_min) > now() then
    return jsonb_build_object('ok', false, 'error', 'interval_limit',
      'retry_at', v_last + make_interval(mins => v_p.stamp_interval_min));
  end if;

  insert into public.used_card_tokens (jti) values (p_jti);
  perform private.lapse_stamps(v_m, v_p, p_location_id, v_staff_id);

  insert into public.stamp_events
    (business_id, membership_id, location_id, staff_id, delta, reason, idempotency_key)
  values (v_m.business_id, v_m.id, p_location_id, v_staff_id, 1, 'stamp', p_idempotency_key);

  select coalesce(sum(delta), 0) into v_stamps from public.stamp_events where membership_id = v_m.id;

  for v_tier in
    select * from public.reward_tiers
    where program_id = v_p.id and stamps_required <= v_stamps order by stamps_required
  loop
    with ins as (
      insert into public.rewards (business_id, membership_id, tier_id, cycle, expires_at)
      values (v_m.business_id, v_m.id, v_tier.id, v_m.cycle,
              case when v_tier.expiry_days is null then null
                   else now() + make_interval(days => v_tier.expiry_days) end)
      on conflict (membership_id, tier_id, cycle) do nothing
      returning id
    )
    select v_new_rewards || coalesce(jsonb_agg(jsonb_build_object(
      'id', ins.id, 'title', v_tier.title, 'stamps_required', v_tier.stamps_required)), '[]'::jsonb)
    into v_new_rewards from ins;
  end loop;

  -- Eng yuqori bosqichga yetilganda karta yangi aylanishni boshlaydi.
  select max(stamps_required) into v_top from public.reward_tiers where program_id = v_p.id;
  if v_top is not null and v_stamps >= v_top then
    insert into public.stamp_events
      (business_id, membership_id, location_id, staff_id, delta, reason, idempotency_key)
    values (v_m.business_id, v_m.id, p_location_id, v_staff_id, -v_top, 'cycle_reset',
            p_idempotency_key || ':reset');
    v_stamps := v_stamps - v_top;
    update public.memberships set stamps = v_stamps, cycle = cycle + 1 where id = v_m.id;
  else
    update public.memberships set stamps = v_stamps where id = v_m.id;
  end if;

  return jsonb_build_object('ok', true, 'duplicate', false, 'stamps', v_stamps,
    'new_rewards', v_new_rewards, 'available_rewards', private.result_rewards(v_m.id));
end;
$$;

-- Mukofot bir marta ishlatiladi; ikkinchi urinish rad etiladi.
create function public.redeem_reward(p_user_id uuid, p_reward_id uuid, p_location_id uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_r public.rewards;
  v_staff_id uuid;
begin
  select * into v_r from public.rewards where id = p_reward_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'reward_not_found');
  end if;

  select id into v_staff_id from public.staff_members
    where user_id = p_user_id and business_id = v_r.business_id and status = 'active'
      and (location_id is null or location_id = p_location_id);
  if v_staff_id is null or not exists (
    select 1 from public.locations where id = p_location_id and business_id = v_r.business_id
  ) then
    return jsonb_build_object('ok', false, 'error', 'wrong_business');
  end if;

  if v_r.status = 'redeemed' then
    return jsonb_build_object('ok', false, 'error', 'already_redeemed');
  end if;
  if v_r.status = 'expired' or (v_r.expires_at is not null and v_r.expires_at <= now()) then
    update public.rewards set status = 'expired' where id = v_r.id;
    return jsonb_build_object('ok', false, 'error', 'reward_expired');
  end if;

  update public.rewards set status = 'redeemed', redeemed_at = now() where id = v_r.id;
  insert into public.stamp_events
    (business_id, membership_id, location_id, staff_id, delta, reason, idempotency_key)
  values (v_r.business_id, v_r.membership_id, p_location_id, v_staff_id, 0, 'redeem',
          'redeem:' || v_r.id);
  return jsonb_build_object('ok', true, 'reward_id', v_r.id);
end;
$$;

-- Kamera ishlamasa: faqat aniq raqam bo'yicha (ro'yxat emas) va o'z biznesida (B-26).
create function public.find_member_by_phone(p_user_id uuid, p_business_id uuid, p_phone text)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_row record;
begin
  if not exists (select 1 from public.staff_members
                 where user_id = p_user_id and business_id = p_business_id and status = 'active') then
    return jsonb_build_object('ok', false, 'error', 'wrong_business');
  end if;
  select m.id, m.stamps, g.name, g.phone into v_row
    from public.memberships m join public.guests g on g.id = m.guest_id
    where m.business_id = p_business_id and g.phone = p_phone and m.status = 'active';
  if not found then
    return jsonb_build_object('ok', false, 'error', 'card_not_found');
  end if;
  return jsonb_build_object('ok', true, 'membership_id', v_row.id, 'stamps', v_row.stamps,
    'name', v_row.name, 'phone', private.mask_phone(v_row.phone));
end;
$$;

-- Kartaga qo'shilish: dastur shartlari majburiy, marketing alohida (L-01, L-02).
create function public.join_program(
  p_user_id uuid, p_phone text, p_slug text, p_name text,
  p_accept_terms boolean, p_marketing boolean
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_program public.loyalty_programs;
  v_guest_id uuid;
  v_membership_id uuid;
begin
  if p_accept_terms is not true then
    return jsonb_build_object('ok', false, 'error', 'terms_required');
  end if;
  select p.* into v_program from public.loyalty_programs p
    join public.businesses b on b.id = p.business_id
    where b.slug = p_slug and b.status = 'active' and p.enabled;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'program_not_found');
  end if;

  insert into public.guests as g (user_id, phone, name)
  values (p_user_id, p_phone, p_name)
  on conflict (user_id) do update set name = coalesce(excluded.name, g.name)
  returning id into v_guest_id;

  insert into public.memberships as m
    (business_id, guest_id, program_id, terms_accepted_at, marketing_consent, consent_at)
  values (v_program.business_id, v_guest_id, v_program.id, now(), coalesce(p_marketing, false),
          case when p_marketing then now() end)
  on conflict (guest_id, program_id) do update
    set status = 'active', terms_accepted_at = now(),
        marketing_consent = excluded.marketing_consent, consent_at = excluded.consent_at
  returning id into v_membership_id;

  return jsonb_build_object('ok', true, 'membership_id', v_membership_id);
end;
$$;

-- Bitta dasturdan chiqish (U-06).
create function public.leave_program(p_user_id uuid, p_membership_id uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  update public.memberships m
    set status = 'left', marketing_consent = false, consent_at = null
    from public.guests g
    where m.id = p_membership_id and g.id = m.guest_id and g.user_id = p_user_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'card_not_found');
  end if;
  delete from public.wallet_passes where membership_id = p_membership_id;
  return jsonb_build_object('ok', true);
end;
$$;

-- Butun hisobni o'chirish: guests qatori ketadi, jurnal bog'lanmagan holda qoladi (U-06).
create function public.delete_guest(p_user_id uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_guest_id uuid;
begin
  select id into v_guest_id from public.guests where user_id = p_user_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'guest_not_found');
  end if;
  delete from public.wallet_passes where membership_id in
    (select id from public.memberships where guest_id = v_guest_id);
  update public.memberships
    set status = 'deleted', marketing_consent = false, consent_at = null, guest_id = null
    where guest_id = v_guest_id;
  delete from public.guests where id = v_guest_id;
  return jsonb_build_object('ok', true);
end;
$$;

-- Wi-Fi paroli bazada shifrlanadi; kalit faqat Edge Function'da.
create function public.set_location_wifi(p_location_id uuid, p_ssid text, p_password text, p_key text)
returns void
language sql security definer set search_path = '' as $$
  update public.locations
    set wifi_ssid = p_ssid,
        wifi_password_enc = case when p_password is null then null
          else extensions.pgp_sym_encrypt(p_password, p_key) end
    where id = p_location_id;
$$;

-- Sahifa va menyu (GET /public/{slug}). Bloklangan biznes faqat holatni qaytaradi (G-08).
create function public.public_page(p_slug text, p_tag_code text, p_wifi_key text)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_b public.businesses;
  v_l public.locations;
  v_tag public.tags;
  v_modules jsonb;
begin
  select * into v_b from public.businesses where slug = p_slug;
  if not found then return null; end if;
  if v_b.status <> 'active' then
    return jsonb_build_object('status', v_b.status, 'name', v_b.name, 'slug', v_b.slug);
  end if;

  if p_tag_code is not null then
    select * into v_tag from public.tags where code = p_tag_code and business_id = v_b.id;
  end if;
  select * into v_l from public.locations
    where business_id = v_b.id and (v_tag.location_id is null or id = v_tag.location_id)
    order by created_at limit 1;
  if not found then return null; end if;

  select modules_json into v_modules from public.plans where id = v_b.plan;

  return jsonb_build_object(
    'status', 'active',
    'name', v_b.name,
    'slug', v_b.slug,
    'brand', v_b.brand_json,
    'show_branding', not coalesce((v_modules ->> 'remove_branding')::boolean, false),
    'modules', v_modules,
    'tag', case when v_tag.id is null then null
      else jsonb_build_object('id', v_tag.id, 'table_label', v_tag.table_label) end,
    'location', jsonb_build_object(
      'id', v_l.id, 'name', v_l.name, 'address', v_l.address, 'timezone', v_l.timezone,
      'google_review_url', v_l.google_review_url, 'wifi_ssid', v_l.wifi_ssid,
      'wifi_password', case when v_l.wifi_password_enc is null or p_wifi_key is null then null
        else extensions.pgp_sym_decrypt(v_l.wifi_password_enc, p_wifi_key) end),
    'items', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', i.kind, 'label', i.label, 'url', i.url) order by i.position)
      from public.landing_items i where i.location_id = v_l.id and i.enabled), '[]'::jsonb),
    'program', (select jsonb_build_object(
        'card', p.card_json,
        'tiers', coalesce((select jsonb_agg(jsonb_build_object(
          'stamps_required', t.stamps_required, 'title', t.title) order by t.stamps_required)
          from public.reward_tiers t where t.program_id = p.id), '[]'::jsonb))
      from public.loyalty_programs p where p.business_id = v_b.id and p.enabled),
    'menus', coalesce((select jsonb_agg(jsonb_build_object(
        'id', m.id, 'name', m.name, 'schedule', m.schedule_json,
        'i18n', (select jsonb_object_agg(tr.field || ':' || tr.locale, tr.value)
                 from public.translations tr
                 where tr.entity_type = 'menu' and tr.entity_id = m.id),
        'categories', coalesce((select jsonb_agg(jsonb_build_object(
          'id', c.id,
          'i18n', (select jsonb_object_agg(tr.field || ':' || tr.locale, tr.value)
                   from public.translations tr
                   where tr.entity_type = 'menu_category' and tr.entity_id = c.id),
          'items', coalesce((select jsonb_agg(jsonb_build_object(
            'id', it.id, 'price_uzs', it.price_uzs, 'photo_url', it.photo_url,
            'tags', it.tags, 'available', it.available,
            'i18n', (select jsonb_object_agg(tr.field || ':' || tr.locale, tr.value)
                     from public.translations tr
                     where tr.entity_type = 'menu_item' and tr.entity_id = it.id)
          ) order by it.position)
          from public.menu_items it where it.category_id = c.id), '[]'::jsonb)
        ) order by c.position)
        from public.menu_categories c where c.menu_id = m.id), '[]'::jsonb)
      ) order by m.position)
      from public.menus m where m.business_id = v_b.id and m.status = 'published'), '[]'::jsonb)
  );
end;
$$;

-- Yangi biznes: egasi, birinchi filial, o'chiq dastur va 30 kunlik sinov (B-01, B-39).
create function public.create_business(p_name text, p_slug text, p_location_name text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_business_id uuid;
begin
  if v_user is null then
    raise exception 'auth required' using errcode = '42501';
  end if;
  insert into public.businesses (name, slug, owner_id)
    values (p_name, p_slug, v_user) returning id into v_business_id;
  insert into public.staff_members (business_id, user_id, role)
    values (v_business_id, v_user, 'owner');
  insert into public.locations (business_id, name) values (v_business_id, p_location_name);
  insert into public.loyalty_programs (business_id) values (v_business_id);
  insert into public.subscriptions (business_id, plan, status, period_end)
    values (v_business_id, 'start', 'trial', now() + interval '30 days');
  return v_business_id;
end;
$$;

-- Mijozlar ro'yxati: telefon raqamini to'liq faqat egasi ko'radi (B-35, B-37).
create function public.business_customers(p_business_id uuid)
returns table (
  membership_id uuid, name text, phone text, stamps integer,
  marketing_consent boolean, last_visit timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
declare
  v_role public.staff_role;
begin
  select role into v_role from public.staff_members
    where user_id = auth.uid() and business_id = p_business_id and status = 'active';
  if v_role is null or v_role = 'cashier' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
    select m.id, g.name,
      case when v_role = 'owner' then g.phone else private.mask_phone(g.phone) end,
      m.stamps, m.marketing_consent,
      (select max(e.created_at) from public.stamp_events e where e.membership_id = m.id)
    from public.memberships m join public.guests g on g.id = m.guest_id
    where m.business_id = p_business_id and m.status = 'active';
end;
$$;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
    public.check_rate_limit(text, integer, integer),
    public.apply_stamp(uuid, uuid, uuid, text, text),
    public.redeem_reward(uuid, uuid, uuid),
    public.find_member_by_phone(uuid, uuid, text),
    public.join_program(uuid, text, text, text, boolean, boolean),
    public.leave_program(uuid, uuid),
    public.delete_guest(uuid),
    public.set_location_wifi(uuid, text, text, text),
    public.public_page(text, text, text)
  to service_role;
grant execute on function public.create_business(text, text, text) to authenticated;
grant execute on function public.business_customers(uuid) to authenticated;

alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
