// Restoran tizimiga Google orqali kirish va admin taklifini email bo'yicha bog'lash.
import assert from 'node:assert/strict';
import { before, test } from 'node:test';
import { createDb, type Db } from './harness.ts';

let db: Db;

before(async () => {
  db = await createDb();
});

async function user(email: string, providers: string[], phone = false): Promise<string> {
  const [row] = await db.sql<{ id: string }>(
    `insert into auth.users (email, raw_app_meta_data, phone_confirmed_at)
     values ($1, jsonb_build_object('providers', $2::jsonb), case when $3 then now() end) returning id`,
    [email, JSON.stringify(providers), phone],
  );
  return row.id;
}

test('Google akkaunti biznes ocha oladi', async () => {
  const owner = await user('egasi@gmail.com', ['google']);
  const [{ id }] = await db.as<{ id: string }>('authenticated', owner, `select public.create_business('Google kafe', 'google-kafe', 'Markaz') as id`);
  const [staff] = await db.sql<{ role: string }>('select role from public.staff_members where business_id = $1 and user_id = $2', [id, owner]);
  assert.equal(staff.role, 'owner');
});

test('faqat email/parol bilan ochilgan hisob biznes ocha olmaydi', async () => {
  const stranger = await user('begona@misol.uz', ['email']);
  await assert.rejects(db.as('authenticated', stranger, `select public.create_business('x', 'begona-kafe', 'y')`), /auth required/);
});

test('taklif qilingan admin hisob ochilganda email bo\'yicha bog\'lanadi, lekin faol emas', async () => {
  await db.sql(`insert into public.admin_users (email, role, status) values ('Boss@Misol.uz', 'super_admin', 'invited')`);
  const id = await user('boss@misol.uz', ['email']);
  const [row] = await db.sql<{ user_id: string; status: string }>(`select user_id, status from public.admin_users where email = 'Boss@Misol.uz'`);
  assert.equal(row.user_id, id);
  assert.equal(row.status, 'invited');
});

test('boshqa email bilan ochilgan hisob adminga bog\'lanmaydi', async () => {
  await db.sql(`insert into public.admin_users (email, role, status) values ('admin2@misol.uz', 'support', 'invited')`);
  await user('boshqa@misol.uz', ['email']);
  const [row] = await db.sql<{ user_id: string | null }>(`select user_id from public.admin_users where email = 'admin2@misol.uz'`);
  assert.equal(row.user_id, null);
});

test('yangi biznes odatiy tugmalar bilan ochiladi', async () => {
  const owner = await user('tugma@gmail.com', ['google']);
  const [{ id }] = await db.as<{ id: string }>('authenticated', owner, `select public.create_business('Tugma', 'tugma-kafe', 'Markaz') as id`);
  const rows = await db.sql<{ kind: string }>('select kind from public.landing_items where business_id = $1 order by position', [id]);
  assert.deepEqual(rows.map((r) => r.kind), ['loyalty', 'menu', 'wifi', 'feedback', 'game']);
});

test('sinov raqami kodi faqat serverga ochiq', async () => {
  await db.sql(`insert into private.test_logins (phone, code) values ('+998900000001', '424242')`);
  assert.equal(await db.rpc('otp_test_code', ['+998900000001']), '424242');
  assert.equal(await db.rpc('otp_test_code', ['+998900000002']), null);
  await assert.rejects(db.as('authenticated', null, `select public.otp_test_code('+998900000001')`), /permission denied/);
  await assert.rejects(db.as('authenticated', null, `select * from private.test_logins`), /permission denied/);
});
