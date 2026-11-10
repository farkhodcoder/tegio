-- 1) Sinov raqamlari: SMS ulanmaguncha (va do'kon tekshiruvi uchun) belgilangan raqam
--    belgilangan kod bilan kiradi. Faqat server o'qiydi; jadval bo'sh bo'lsa hech narsa o'zgarmaydi.
create table if not exists private.test_logins (
  phone text primary key check (phone ~ '^\+[0-9]{9,15}$'),
  code text not null check (code ~ '^[0-9]{6}$'),
  note text,
  created_at timestamptz not null default now()
);
alter table private.test_logins enable row level security;
revoke all on private.test_logins from public, anon, authenticated;

create or replace function public.otp_test_code(p_phone text) returns text
language sql stable security definer set search_path = '' as $$
  select code from private.test_logins where phone = p_phone;
$$;
revoke execute on function public.otp_test_code(text) from public, anon, authenticated;
grant execute on function public.otp_test_code(text) to service_role;

-- 2) Yangi biznes sahifasi bo'sh ochilmasin: odatiy tugmalar namunadagi tartibda.
create or replace function public.create_business(p_name text, p_slug text, p_location_name text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_business_id uuid;
  v_location_id uuid;
begin
  if v_user is null or not private.can_open_business(v_user) then
    raise exception 'auth required' using errcode = '42501';
  end if;
  insert into public.businesses (name, slug, owner_id, plan)
    values (p_name, p_slug, v_user, 'start') returning id into v_business_id;
  insert into public.staff_members (business_id, user_id, role)
    values (v_business_id, v_user, 'owner');
  insert into public.locations (business_id, name) values (v_business_id, p_location_name)
    returning id into v_location_id;
  insert into public.landing_items (business_id, location_id, kind, position)
    select v_business_id, v_location_id, kind, ord - 1
    from unnest(array['loyalty', 'menu', 'wifi', 'feedback', 'game']) with ordinality as k(kind, ord);
  insert into public.loyalty_programs (business_id) values (v_business_id);
  insert into public.subscriptions (business_id, plan, status, period_end)
    values (v_business_id, 'start', 'trial', now() + interval '30 days');
  return v_business_id;
end;
$$;

-- 3) Mavjud bizneslarga o'yin tugmasi (sayt endi o'yinni faqat shu tugma bo'lsa ko'rsatadi).
insert into public.landing_items (business_id, location_id, kind, position)
select l.business_id, l.id, 'game', coalesce((select max(position) + 1 from public.landing_items i where i.location_id = l.id), 0)
from public.locations l
where not exists (select 1 from public.landing_items i where i.location_id = l.id and i.kind = 'game');
