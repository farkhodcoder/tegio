// Izolyatsiya: "Bir biznes boshqa biznes ma'lumotini ko'ra olmaydi" (TTZ 8, 11-bo'limlar).
import assert from 'node:assert/strict';
import { before, test } from 'node:test';
import { createDb, createTenant, joinGuest, type Db, type Tenant } from './harness.ts';

let db: Db;
let a: Tenant;
let b: Tenant;
let guestA: Awaited<ReturnType<typeof joinGuest>>;

before(async () => {
  db = await createDb();
  a = await createTenant(db, 0);
  b = await createTenant(db);
  guestA = await joinGuest(db, a);

  // A biznesning har bir jadvalida qator bo'lishi kerak, aks holda izolyatsiya sinovi hech narsani isbotlamaydi.
  await db.rpc('apply_stamp', [a.cashier, guestA.membershipId, a.locationId, 'j1', 'k1']);
  await db.rpc('apply_stamp', [a.cashier, guestA.membershipId, a.locationId, 'j2', 'k2']);
  const id = a.businessId;
  const loc = a.locationId;
  await db.sql(`insert into public.tags (code, business_id, location_id) values ('A1', $1, $2)`, [id, loc]);
  await db.sql(`insert into public.landing_items (business_id, location_id, kind) values ($1, $2, 'menu')`, [id, loc]);
  await db.sql(`insert into public.translations (business_id, entity_type, entity_id, field, locale, value) values ($1, 'menu_category', $2, 'name', 'uz', 'Osh')`, [id, a.categoryId]);
  await db.sql(`insert into public.wallet_passes (business_id, membership_id, platform, serial) values ($1, $2, 'apple', 's1')`, [id, guestA.membershipId]);
  await db.sql(`insert into public.feedback (business_id, location_id, rating) values ($1, $2, 5)`, [id, loc]);
  await db.sql(`insert into public.scan_events (business_id, location_id, action) values ($1, $2, 'scan')`, [id, loc]);
  await db.sql(`insert into public.payments (business_id, amount_uzs, provider, status) values ($1, 149000, 'click', 'paid')`, [id]);
  await db.sql(`insert into public.support_tickets (business_id, subject) values ($1, 'Savol')`, [id]);
});

const denied = (promise: Promise<unknown>) => assert.rejects(promise, /permission denied/);

test('NFR Izolyatsiya: public sxemadagi har bir jadvalda RLS yoqilgan', async () => {
  const rows = await db.sql<{ tablename: string }>(
    `select tablename from pg_tables where schemaname = 'public' and not rowsecurity`,
  );
  assert.deepEqual(rows, []);
});

const tenantTables = [
  'locations', 'staff_members', 'tags', 'landing_items', 'menus', 'menu_categories',
  'menu_items', 'translations', 'loyalty_programs', 'reward_tiers', 'memberships',
  'stamp_events', 'rewards', 'wallet_passes', 'feedback', 'scan_events', 'subscriptions',
  'payments', 'support_tickets',
];

for (const table of tenantTables) {
  test(`NFR Izolyatsiya: B egasi ${table} jadvalida A qatorlarini ko'rmaydi`, async () => {
    const existing = await db.sql(`select 1 from public.${table} where business_id = $1`, [a.businessId]);
    assert.ok(existing.length > 0, 'A biznesda qator yo\'q, sinov bo\'sh');
    const rows = await db.as('authenticated', b.owner, `select business_id from public.${table} where business_id = $1`, [a.businessId]);
    assert.equal(rows.length, 0);
  });
}

test('NFR Izolyatsiya: anon hech qaysi biznes jadvalini o\'qiy olmaydi', async () => {
  for (const table of ['businesses', 'guests', 'memberships', 'menus', 'feedback', 'admin_users', 'audit_log']) {
    const rows = await db.as('anon', null, `select * from public.${table}`);
    assert.equal(rows.length, 0, table);
  }
});

test('xodim o\'z biznesi menyusini ko\'radi', async () => {
  const rows = await db.as('authenticated', a.cashier, 'select id from public.menus where business_id = $1', [a.businessId]);
  assert.equal(rows.length, 1);
});

test('B menejeri A menyusiga taom qo\'sha olmaydi', async () => {
  await assert.rejects(
    db.as('authenticated', b.manager, 'insert into public.menu_items (business_id, category_id, price_uzs) values ($1, $2, 1)', [a.businessId, a.categoryId]),
    /row-level security/,
  );
});

test('B menejeri A narxini o\'zgartira olmaydi', async () => {
  const rows = await db.as('authenticated', b.manager, 'update public.menu_items set price_uzs = 1 where business_id = $1 returning id', [a.businessId]);
  assert.equal(rows.length, 0);
});

test('o\'z biznes_id bilan boshqa biznes kategoriyasiga ulanib bo\'lmaydi', async () => {
  await assert.rejects(
    db.as('authenticated', b.manager, 'insert into public.menu_items (business_id, category_id, price_uzs) values ($1, $2, 1)', [b.businessId, a.categoryId]),
    /foreign key/,
  );
});

test('kassir menyuni tahrirlay olmaydi', async () => {
  const rows = await db.as('authenticated', a.cashier, 'update public.menu_items set price_uzs = 1 where business_id = $1 returning id', [a.businessId]);
  assert.equal(rows.length, 0);
});

test('egasi tarif va holatni o\'zi o\'zgartira olmaydi', async () => {
  await denied(db.as('authenticated', a.owner, `update public.businesses set plan = 'pro' where id = $1`, [a.businessId]));
  await denied(db.as('authenticated', a.owner, `update public.businesses set status = 'active' where id = $1`, [a.businessId]));
});

test('egasi nomini o\'zgartira oladi', async () => {
  const rows = await db.as('authenticated', a.owner, `update public.businesses set city = 'Toshkent' where id = $1 returning id`, [a.businessId]);
  assert.equal(rows.length, 1);
});

test('Wi-Fi shifrlangan matni mijozga berilmaydi', async () => {
  await denied(db.as('authenticated', a.owner, 'select wifi_password_enc from public.locations where business_id = $1', [a.businessId]));
});

test('mehmon faqat o\'z kartasini ko\'radi', async () => {
  const other = await joinGuest(db, a);
  const mine = await db.as<{ id: string }>('authenticated', guestA.user, 'select id from public.memberships');
  assert.deepEqual(mine.map((r) => r.id), [guestA.membershipId]);
  const guests = await db.as('authenticated', guestA.user, 'select id from public.guests where user_id = $1', [other.user]);
  assert.equal(guests.length, 0);
});

test('mehmon o\'zi shtamp yoza olmaydi', async () => {
  await assert.rejects(
    db.as('authenticated', guestA.user, 'update public.memberships set stamps = 99 where id = $1 returning id', [guestA.membershipId]).then((rows) => {
      if (rows.length === 0) throw new Error('permission denied (no rows)');
    }),
    /permission denied/,
  );
});

test('xodim mehmon jadvalini to\'g\'ridan-to\'g\'ri ko\'rmaydi', async () => {
  const rows = await db.as('authenticated', a.owner, 'select phone from public.guests');
  assert.equal(rows.length, 0);
});

test('B-35, B-37: telefonni to\'liq faqat egasi ko\'radi', async () => {
  const [ownerRow] = await db.as<{ phone: string }>('authenticated', a.owner, 'select phone from public.business_customers($1) limit 1', [a.businessId]);
  const [managerRow] = await db.as<{ phone: string }>('authenticated', a.manager, 'select phone from public.business_customers($1) limit 1', [a.businessId]);
  assert.match(ownerRow.phone, /^\+\d+$/);
  assert.match(managerRow.phone, /\*{3,}/);
  await assert.rejects(db.as('authenticated', a.cashier, 'select * from public.business_customers($1)', [a.businessId]), /forbidden/);
  await assert.rejects(db.as('authenticated', b.owner, 'select * from public.business_customers($1)', [a.businessId]), /forbidden/);
});

for (const fn of [
  `public.apply_stamp(gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'j', 'k')`,
  `public.redeem_reward(gen_random_uuid(), gen_random_uuid(), gen_random_uuid())`,
  `public.public_page('x', null, 'key')`,
  `public.delete_guest(gen_random_uuid())`,
]) {
  test(`mijoz ${fn.split('(')[0]} ni bevosita chaqira olmaydi`, async () => {
    await denied(db.as('authenticated', a.cashier, `select ${fn}`));
    await denied(db.as('anon', null, `select ${fn}`));
  });
}
