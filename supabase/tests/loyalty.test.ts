// Shtamp, mukofot, jurnal va mehmon ma'lumotini o'chirish.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { before, test } from 'node:test';
import { createDb, createTenant, joinGuest, type Db, type Tenant } from './harness.ts';

let db: Db;
let t: Tenant;
let other: Tenant;

before(async () => {
  db = await createDb();
  t = await createTenant(db, 0);
  other = await createTenant(db, 0);
});

const stamp = (tenant: Tenant, membershipId: string, jti = randomUUID(), key = randomUUID(), user = tenant.cashier) =>
  db.rpc('apply_stamp', [user, membershipId, tenant.locationId, jti, key]);

const stored = async (id: string) =>
  (await db.sql<{ stamps: number }>('select stamps from public.memberships where id = $1', [id]))[0].stamps;

test('B-24: shtamp qo\'yiladi va hisob jurnaldan chiqadi', async () => {
  const g = await joinGuest(db, t);
  const result = await stamp(t, g.membershipId);
  assert.equal(result.ok, true);
  assert.equal(result.stamps, 1);
  assert.equal(await stored(g.membershipId), 1);
});

test('B-29: bir xil idempotency_key bilan bitta shtamp', async () => {
  const g = await joinGuest(db, t);
  const key = randomUUID();
  const jti = randomUUID();
  await stamp(t, g.membershipId, jti, key);
  const second = await stamp(t, g.membershipId, jti, key);
  assert.equal(second.ok, true);
  assert.equal(second.duplicate, true);
  assert.equal(await stored(g.membershipId), 1);
});

test('Qabul: QR ikkinchi marta ishlamaydi', async () => {
  const g = await joinGuest(db, t);
  const jti = randomUUID();
  await stamp(t, g.membershipId, jti);
  const second = await stamp(t, g.membershipId, jti);
  assert.deepEqual(second, { ok: false, error: 'qr_used' });
  assert.equal(await stored(g.membershipId), 1);
});

test('B-18: belgilangan oraliqda 1 shtamp', async () => {
  const limited = await createTenant(db, 60);
  const g = await joinGuest(db, limited);
  await stamp(limited, g.membershipId);
  const second = await stamp(limited, g.membershipId);
  assert.equal(second.ok, false);
  assert.equal(second.error, 'interval_limit');
  assert.ok(second.retry_at);
  assert.equal(await stored(g.membershipId), 1);
});

test('B-25: rad etilgan urinish QR\'ni kuydirmaydi', async () => {
  const limited = await createTenant(db, 60);
  const g = await joinGuest(db, limited);
  await stamp(limited, g.membershipId);
  const jti = randomUUID();
  await stamp(limited, g.membershipId, jti);
  const used = await db.sql('select 1 from public.used_card_tokens where jti = $1', [jti]);
  assert.equal(used.length, 0);
});

test('B-25: boshqa biznes kassiri kartaga shtamp qo\'ya olmaydi', async () => {
  const g = await joinGuest(db, t);
  const result = await db.rpc('apply_stamp', [other.cashier, g.membershipId, other.locationId, randomUUID(), randomUUID()]);
  assert.deepEqual(result, { ok: false, error: 'wrong_business' });
  assert.equal(await stored(g.membershipId), 0);
});

test('B-25: o\'z kassiri boshqa biznes filialini ko\'rsata olmaydi', async () => {
  const g = await joinGuest(db, t);
  const result = await db.rpc('apply_stamp', [t.cashier, g.membershipId, other.locationId, randomUUID(), randomUUID()]);
  assert.deepEqual(result, { ok: false, error: 'wrong_business' });
});

test('boshqa kartadagi idempotency_key qayta ishlatilmaydi', async () => {
  const g1 = await joinGuest(db, t);
  const g2 = await joinGuest(db, t);
  const key = randomUUID();
  await stamp(t, g1.membershipId, randomUUID(), key);
  const result = await stamp(t, g2.membershipId, randomUUID(), key);
  assert.deepEqual(result, { ok: false, error: 'idempotency_conflict' });
});

test('B-17: bosqichli mukofot va yangi aylanish', async () => {
  const g = await joinGuest(db, t);
  assert.deepEqual((await stamp(t, g.membershipId)).new_rewards, []);
  const atTwo = await stamp(t, g.membershipId);
  assert.equal(atTwo.new_rewards[0].title, 'Pishiriq');
  const atThree = await stamp(t, g.membershipId);
  assert.equal(atThree.new_rewards[0].title, 'Qahva');
  assert.equal(atThree.stamps, 0);
  const [{ cycle }] = await db.sql<{ cycle: number }>('select cycle from public.memberships where id = $1', [g.membershipId]);
  assert.equal(cycle, 1);
  await stamp(t, g.membershipId);
  const again = await stamp(t, g.membershipId);
  assert.equal(again.new_rewards[0].title, 'Pishiriq', 'yangi aylanishda mukofot qayta beriladi');
});

test('memberships.stamps jurnal yig\'indisiga teng', async () => {
  const g = await joinGuest(db, t);
  for (let i = 0; i < 4; i++) await stamp(t, g.membershipId);
  const [{ total }] = await db.sql<{ total: number }>('select coalesce(sum(delta), 0)::int as total from public.stamp_events where membership_id = $1', [g.membershipId]);
  assert.equal(total, await stored(g.membershipId));
});

test('Qabul: mukofot bir marta ishlatiladi', async () => {
  const g = await joinGuest(db, t);
  await stamp(t, g.membershipId);
  const { new_rewards: [reward] } = await stamp(t, g.membershipId);
  assert.deepEqual(await db.rpc('redeem_reward', [t.cashier, reward.id, t.locationId]), { ok: true, reward_id: reward.id });
  assert.deepEqual(await db.rpc('redeem_reward', [t.cashier, reward.id, t.locationId]), { ok: false, error: 'already_redeemed' });
});

test('B-19: muddati o\'tgan mukofot ishlatilmaydi', async () => {
  const g = await joinGuest(db, t);
  await stamp(t, g.membershipId);
  const { new_rewards: [reward] } = await stamp(t, g.membershipId);
  await db.sql(`update public.rewards set expires_at = now() - interval '1 day' where id = $1`, [reward.id]);
  assert.deepEqual(await db.rpc('redeem_reward', [t.cashier, reward.id, t.locationId]), { ok: false, error: 'reward_expired' });
});

test('B-19: muddati o\'tgan shtamplar jurnal orqali yonadi', async () => {
  const expiring = await createTenant(db, 0);
  await db.sql('update public.loyalty_programs set stamp_expiry_days = 30 where id = $1', [expiring.programId]);
  const g = await joinGuest(db, expiring);
  await stamp(expiring, g.membershipId);
  await db.pg.exec('alter table public.stamp_events disable trigger stamp_events_append_only');
  await db.sql(`update public.stamp_events set created_at = now() - interval '31 days' where membership_id = $1`, [g.membershipId]);
  await db.pg.exec('alter table public.stamp_events enable trigger stamp_events_append_only');
  const result = await stamp(expiring, g.membershipId);
  assert.equal(result.stamps, 1);
  const [{ n }] = await db.sql<{ n: number }>(`select count(*)::int as n from public.stamp_events where membership_id = $1 and reason = 'expiry'`, [g.membershipId]);
  assert.equal(n, 1);
});

test('B-28: jurnalni o\'zgartirib yoki o\'chirib bo\'lmaydi, service_role ham', async () => {
  const g = await joinGuest(db, t);
  await stamp(t, g.membershipId);
  await assert.rejects(db.as('service_role', null, 'update public.stamp_events set delta = 5 where membership_id = $1', [g.membershipId]), /faqat qo'shiladi/);
  await assert.rejects(db.as('service_role', null, 'delete from public.stamp_events where membership_id = $1', [g.membershipId]), /faqat qo'shiladi/);
  await assert.rejects(db.as('service_role', null, 'truncate public.stamp_events cascade'), /faqat qo'shiladi|permission denied/);
});

test('P-30: audit_log o\'zgartirilmaydi', async () => {
  await db.sql(`insert into public.audit_log (action, entity) values ('test', 'test')`);
  await assert.rejects(db.as('service_role', null, `update public.audit_log set action = 'x'`), /faqat qo'shiladi/);
});

test('L-02: dastur shartlarisiz kartaga qo\'shilib bo\'lmaydi', async () => {
  const user = await db.newUser();
  const [{ slug }] = await db.sql<{ slug: string }>('select slug from public.businesses where id = $1', [t.businessId]);
  const result = await db.rpc('join_program', [user, '+998909999999', slug, 'X', false, false]);
  assert.deepEqual(result, { ok: false, error: 'terms_required' });
});

test('L-02: marketing roziligi alohida saqlanadi', async () => {
  const yes = await joinGuest(db, t, true);
  const no = await joinGuest(db, t, false);
  const consent = async (id: string) => (await db.sql<{ marketing_consent: boolean; consent_at: string | null }>('select marketing_consent, consent_at from public.memberships where id = $1', [id]))[0];
  assert.equal((await consent(yes.membershipId)).marketing_consent, true);
  assert.ok((await consent(yes.membershipId)).consent_at);
  assert.equal((await consent(no.membershipId)).marketing_consent, false);
  assert.equal((await consent(no.membershipId)).consent_at, null);
});

test('U-06: dasturdan chiqilgach karta skan bo\'lmaydi', async () => {
  const g = await joinGuest(db, t);
  assert.deepEqual(await db.rpc('leave_program', [g.user, g.membershipId]), { ok: true });
  assert.deepEqual(await stamp(t, g.membershipId), { ok: false, error: 'card_not_found' });
});

test('U-06: boshqa mehmon kartasidan chiqib bo\'lmaydi', async () => {
  const g = await joinGuest(db, t);
  const intruder = await db.newUser();
  assert.deepEqual(await db.rpc('leave_program', [intruder, g.membershipId]), { ok: false, error: 'card_not_found' });
});

test('U-06: hisob o\'chiriladi, jurnal shaxssiz qoladi', async () => {
  const g = await joinGuest(db, t);
  await stamp(t, g.membershipId);
  assert.deepEqual(await db.rpc('delete_guest', [g.user]), { ok: true });
  assert.equal((await db.sql('select 1 from public.guests where phone = $1', [g.phone])).length, 0);
  const [m] = await db.sql<{ guest_id: string | null; status: string }>('select guest_id, status from public.memberships where id = $1', [g.membershipId]);
  assert.equal(m.guest_id, null);
  assert.equal(m.status, 'deleted');
  assert.equal((await db.sql('select 1 from public.stamp_events where membership_id = $1', [g.membershipId])).length, 1);
});

test('B-26: telefon bo\'yicha faqat o\'z biznesida, raqam yashirin', async () => {
  const g = await joinGuest(db, t);
  const found = await db.rpc('find_member_by_phone', [t.cashier, t.businessId, g.phone]);
  assert.equal(found.membership_id, g.membershipId);
  assert.match(found.phone, /\*{3,}/);
  assert.deepEqual(await db.rpc('find_member_by_phone', [other.cashier, t.businessId, g.phone]), { ok: false, error: 'wrong_business' });
  assert.deepEqual(await db.rpc('find_member_by_phone', [other.cashier, other.businessId, g.phone]), { ok: false, error: 'card_not_found' });
});

test('NFR Wi-Fi: parol bazada shifrlangan va sahifada ochiladi', async () => {
  await db.rpc('set_location_wifi', [t.locationId, 'Anor-Guest', 'maxfiy12345', 'kalit']);
  const [row] = await db.sql<{ enc: string }>(`select encode(wifi_password_enc, 'escape') as enc from public.locations where id = $1`, [t.locationId]);
  assert.ok(!row.enc.includes('maxfiy12345'));
  const [{ slug }] = await db.sql<{ slug: string }>('select slug from public.businesses where id = $1', [t.businessId]);
  const page = await db.rpc('public_page', [slug, null, 'kalit']);
  assert.equal(page.location.wifi_ssid, 'Anor-Guest');
  assert.equal(page.location.wifi_password, 'maxfiy12345');
  assert.equal((await db.rpc('public_page', [slug, null, null])).location.wifi_password, null);
});

test('G-08: bloklangan biznes menyu qaytarmaydi', async () => {
  const blocked = await createTenant(db);
  const [{ slug }] = await db.sql<{ slug: string }>(`update public.businesses set status = 'blocked' where id = $1 returning slug`, [blocked.businessId]);
  const page = await db.rpc('public_page', [slug, null, 'kalit']);
  assert.equal(page.status, 'blocked');
  assert.equal(page.menus, undefined);
});

test('G-01: yorliq o\'z filialini ochadi, boshqa biznes yorlig\'i hisobga olinmaydi', async () => {
  const [second] = await db.sql<{ id: string }>(`insert into public.locations (business_id, name) values ($1, 'Ikkinchi') returning id`, [t.businessId]);
  await db.sql(`insert into public.tags (code, business_id, location_id, table_label) values ('STOL7', $1, $2, '7')`, [t.businessId, second.id]);
  const [{ slug }] = await db.sql<{ slug: string }>('select slug from public.businesses where id = $1', [t.businessId]);
  const [{ slug: otherSlug }] = await db.sql<{ slug: string }>('select slug from public.businesses where id = $1', [other.businessId]);
  const page = await db.rpc('public_page', [slug, 'STOL7', null]);
  assert.equal(page.location.id, second.id);
  assert.equal(page.tag.table_label, '7');
  assert.equal((await db.rpc('public_page', [otherSlug, 'STOL7', null])).tag, null);
});

test('G-07: Pro tarifda TEGIO belgisi olib tashlanadi', async () => {
  const pro = await createTenant(db);
  const [{ slug }] = await db.sql<{ slug: string }>(`update public.businesses set plan = 'pro' where id = $1 returning slug`, [pro.businessId]);
  assert.equal((await db.rpc('public_page', [slug, null, null])).show_branding, false);
  const [{ slug: freeSlug }] = await db.sql<{ slug: string }>('select slug from public.businesses where id = $1', [t.businessId]);
  assert.equal((await db.rpc('public_page', [freeSlug, null, null])).show_branding, true);
});

test('NFR Suiiste\'mol: limit oshganda rad etiladi', async () => {
  const key = `otp:${randomUUID()}`;
  assert.equal(await db.rpc('check_rate_limit', [key, 3600, 2]), true);
  assert.equal(await db.rpc('check_rate_limit', [key, 3600, 2]), true);
  assert.equal(await db.rpc('check_rate_limit', [key, 3600, 2]), false);
});

test('band so\'zlar slug bo\'la olmaydi', async () => {
  const owner = await db.newUser();
  await assert.rejects(db.as('authenticated', owner, `select public.create_business('x', 'me', 'y')`), /check constraint/);
});

test('B-39: yangi biznes 30 kunlik sinov bilan boshlanadi', async () => {
  const [s] = await db.sql<{ status: string; days: number }>(
    `select status, round(extract(epoch from period_end - now()) / 86400)::int as days from public.subscriptions where business_id = $1`,
    [t.businessId],
  );
  assert.equal(s.status, 'trial');
  assert.equal(s.days, 30);
});

test('M-05: menyu nomi tarjimasi sahifada qaytadi', async () => {
  const [{ id: menuId }] = await db.sql<{ id: string }>('select id from public.menus where business_id = $1', [other.businessId]);
  await db.sql(`insert into public.translations (business_id, entity_type, entity_id, field, locale, value) values ($1, 'menu', $2, 'name', 'ru', 'Блюда')`, [other.businessId, menuId]);
  const [{ slug }] = await db.sql<{ slug: string }>('select slug from public.businesses where id = $1', [other.businessId]);
  const page = await db.rpc('public_page', [slug, null, null]);
  assert.equal(page.menus[0].i18n['name:ru'], 'Блюда');
});
