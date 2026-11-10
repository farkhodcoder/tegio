-- Restoran tizimiga Google orqali kirish va adminni email bo'yicha bog'lash.

-- Biznesni tasdiqlangan telefon yoki Google akkaunti ochadi.
create or replace function private.can_open_business(p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from auth.users
    where id = p_user
      and (phone_confirmed_at is not null or coalesce(raw_app_meta_data -> 'providers', '[]'::jsonb) ? 'google')
  );
$$;

create or replace function public.create_business(p_name text, p_slug text, p_location_name text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_business_id uuid;
begin
  if v_user is null or not private.can_open_business(v_user) then
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

-- Taklif qilingan admin (user_id hali yo'q) shu email bilan hisob ochilganda unga bog'lanadi.
-- Admin baribir faqat TOTP'dan keyin faol bo'ladi (admin_activate).
create or replace function private.link_admin_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.email is not null then
    update public.admin_users set user_id = new.id
      where user_id is null and lower(email) = lower(new.email);
  end if;
  return new;
end;
$$;

drop trigger if exists link_admin_user on auth.users;
create trigger link_admin_user after insert on auth.users
  for each row execute function private.link_admin_user();
