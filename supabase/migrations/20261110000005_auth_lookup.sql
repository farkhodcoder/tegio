-- OTP tasdiqlangach mavjud foydalanuvchini telefon bo'yicha topish.
create function public.auth_user_id_by_phone(p_phone text) returns uuid
language sql stable security definer set search_path = '' as $$
  select id from auth.users where phone = ltrim(p_phone, '+') limit 1;
$$;

revoke execute on function public.auth_user_id_by_phone(text) from public, anon, authenticated;
grant execute on function public.auth_user_id_by_phone(text) to service_role;
