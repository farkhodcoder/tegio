-- Biznes bo'yicha izolyatsiya. Har bir jadvalda RLS yoqiladi; siyosat
-- yozilmagan jadvalga mijozlar umuman kira olmaydi (faqat Edge Functions).

do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

create function private.staff_business_ids(roles public.staff_role[])
returns setof uuid
language sql stable security definer set search_path = '' as $$
  select business_id from public.staff_members
  where user_id = auth.uid() and status = 'active' and role = any (roles);
$$;

create function private.guest_membership_ids()
returns setof uuid
language sql stable security definer set search_path = '' as $$
  select m.id from public.memberships m
  join public.guests g on g.id = m.guest_id
  where g.user_id = auth.uid();
$$;

grant usage on schema private to authenticated;
revoke execute on all functions in schema private from public, anon;
grant execute on function private.staff_business_ids(public.staff_role[]) to authenticated;
grant execute on function private.guest_membership_ids() to authenticated;

-- Ochiq ma'lumot: narxlar va bosh sayt matnlari.
create policy plans_read on public.plans for select to anon, authenticated using (true);
create policy site_content_read on public.site_content for select to anon, authenticated using (true);

-- Barcha xodim ko'radi, egasi va menejer tahrirlaydi.
do $$
declare t text;
begin
  foreach t in array array[
    'landing_items', 'menus', 'menu_categories', 'menu_items', 'translations',
    'loyalty_programs', 'reward_tiers', 'tags'
  ] loop
    execute format($f$
      create policy %1$s_staff_read on public.%1$I for select to authenticated
        using (business_id in (select private.staff_business_ids('{owner,manager,cashier}')));
      create policy %1$s_manage_insert on public.%1$I for insert to authenticated
        with check (business_id in (select private.staff_business_ids('{owner,manager}')));
      create policy %1$s_manage_update on public.%1$I for update to authenticated
        using (business_id in (select private.staff_business_ids('{owner,manager}')))
        with check (business_id in (select private.staff_business_ids('{owner,manager}')));
      create policy %1$s_manage_delete on public.%1$I for delete to authenticated
        using (business_id in (select private.staff_business_ids('{owner,manager}')));
    $f$, t);
  end loop;
end $$;

-- Faqat o'qish: yozuvlar RPC orqali tranzaksiyada qilinadi.
do $$
declare t text;
begin
  foreach t in array array['stamp_events', 'rewards', 'memberships'] loop
    execute format($f$
      create policy %1$s_staff_read on public.%1$I for select to authenticated
        using (business_id in (select private.staff_business_ids('{owner,manager,cashier}')));
    $f$, t);
  end loop;
end $$;

create policy memberships_guest_read on public.memberships for select to authenticated
  using (id in (select private.guest_membership_ids()));
create policy stamp_events_guest_read on public.stamp_events for select to authenticated
  using (membership_id in (select private.guest_membership_ids()));
create policy rewards_guest_read on public.rewards for select to authenticated
  using (membership_id in (select private.guest_membership_ids()));

create policy businesses_staff_read on public.businesses for select to authenticated
  using (id in (select private.staff_business_ids('{owner,manager,cashier}')));
create policy businesses_owner_update on public.businesses for update to authenticated
  using (id in (select private.staff_business_ids('{owner}')))
  with check (id in (select private.staff_business_ids('{owner}')));
-- Tarif va holatni faqat admin o'zgartiradi.
revoke update on public.businesses from authenticated, anon;
grant update (name, slug, brand_json, city) on public.businesses to authenticated;

create policy locations_staff_read on public.locations for select to authenticated
  using (business_id in (select private.staff_business_ids('{owner,manager,cashier}')));
create policy locations_owner_insert on public.locations for insert to authenticated
  with check (business_id in (select private.staff_business_ids('{owner}')));
create policy locations_manage_update on public.locations for update to authenticated
  using (business_id in (select private.staff_business_ids('{owner,manager}')))
  with check (business_id in (select private.staff_business_ids('{owner,manager}')));
-- Shifrlangan parol mijozga umuman berilmaydi; yozish set_location_wifi orqali.
revoke select, insert, update on public.locations from authenticated, anon;
grant select (id, business_id, name, address, lat, lng, timezone, wifi_ssid, google_review_url, created_at)
  on public.locations to authenticated;
grant insert (business_id, name, address, lat, lng, timezone) on public.locations to authenticated;
grant update (name, address, lat, lng, timezone, google_review_url) on public.locations to authenticated;

create policy staff_members_read on public.staff_members for select to authenticated
  using (business_id in (select private.staff_business_ids('{owner,manager,cashier}')));
create policy staff_members_owner_insert on public.staff_members for insert to authenticated
  with check (business_id in (select private.staff_business_ids('{owner}')));
create policy staff_members_owner_update on public.staff_members for update to authenticated
  using (business_id in (select private.staff_business_ids('{owner}')))
  with check (business_id in (select private.staff_business_ids('{owner}')));

create policy feedback_staff_read on public.feedback for select to authenticated
  using (business_id in (select private.staff_business_ids('{owner,manager}')));
create policy feedback_manage_update on public.feedback for update to authenticated
  using (business_id in (select private.staff_business_ids('{owner,manager}')))
  with check (business_id in (select private.staff_business_ids('{owner,manager}')));
revoke update on public.feedback from authenticated, anon;
grant update (status, reply) on public.feedback to authenticated;

create policy scan_events_staff_read on public.scan_events for select to authenticated
  using (business_id in (select private.staff_business_ids('{owner,manager}')));

create policy subscriptions_owner_read on public.subscriptions for select to authenticated
  using (business_id in (select private.staff_business_ids('{owner}')));
create policy payments_owner_read on public.payments for select to authenticated
  using (business_id in (select private.staff_business_ids('{owner}')));

create policy support_tickets_owner_read on public.support_tickets for select to authenticated
  using (business_id in (select private.staff_business_ids('{owner,manager}')));
create policy support_tickets_owner_insert on public.support_tickets for insert to authenticated
  with check (business_id in (select private.staff_business_ids('{owner,manager}')));

-- Mehmon faqat o'zini ko'radi. Xodimlar telefonni faqat business_customers orqali oladi.
create policy guests_self_read on public.guests for select to authenticated
  using (user_id = auth.uid());
create policy guests_self_update on public.guests for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke update on public.guests from authenticated, anon;
grant update (name, birthday, locale) on public.guests to authenticated;
