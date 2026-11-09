// NFR Xavfsizlik: QR tokeni imzolangan va 60 soniya amal qiladi (L-04).
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { signCardToken, verifyCardToken } from '../functions/_shared/card_token.ts';

const SECRET = 'test-secret';
const NOW = 1_800_000_000;

test('L-04: to\'g\'ri token tekshiruvdan o\'tadi', async () => {
  const { token, expiresAt } = await signCardToken('m1', SECRET, NOW);
  assert.equal(expiresAt, NOW + 60);
  const result = await verifyCardToken(token, SECRET, NOW + 59);
  assert.equal(result.ok, true);
  assert.equal(result.ok && result.payload.mid, 'm1');
});

test('L-04: 60 soniyadan keyin eskiradi', async () => {
  const { token } = await signCardToken('m1', SECRET, NOW);
  assert.deepEqual(await verifyCardToken(token, SECRET, NOW + 60), { ok: false, error: 'qr_expired' });
});

test('har bir token noyob jti oladi', async () => {
  const one = await signCardToken('m1', SECRET, NOW);
  const two = await signCardToken('m1', SECRET, NOW);
  assert.notEqual(one.token, two.token);
});

test('boshqa kalit bilan imzolangan token rad etiladi', async () => {
  const { token } = await signCardToken('m1', 'boshqa', NOW);
  assert.deepEqual(await verifyCardToken(token, SECRET, NOW), { ok: false, error: 'qr_invalid' });
});

test('o\'zgartirilgan token rad etiladi', async () => {
  const { token } = await signCardToken('m1', SECRET, NOW);
  const [, signature] = token.split('.');
  const forged = Buffer.from(JSON.stringify({ mid: 'hacker', jti: 'x', exp: NOW + 1000 })).toString('base64url');
  assert.deepEqual(await verifyCardToken(`${forged}.${signature}`, SECRET, NOW), { ok: false, error: 'qr_invalid' });
});

test('buzuq satrlar xatoga olib kelmaydi', async () => {
  for (const bad of ['', 'abc', 'a.b.c', '!!!.???']) {
    assert.deepEqual(await verifyCardToken(bad, SECRET, NOW), { ok: false, error: 'qr_invalid' }, bad);
  }
});
