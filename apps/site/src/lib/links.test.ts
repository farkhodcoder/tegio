import assert from 'node:assert/strict';
import { test } from 'node:test';
import { isLocalOrigin, safeHttpUrl, tagUrl, wifiQrPayload } from './links.ts';

test('B-08: yorliq havolasi /{kafe}?t={yorliq} shaklida', () => {
  assert.equal(tagUrl('https://tegio.uz', 'anor', 'S7'), 'https://tegio.uz/anor?t=S7');
  assert.equal(tagUrl('https://tegio.uz', 'anor', 'a&b'), 'https://tegio.uz/anor?t=a%26b');
});

test('W-02: Wi-Fi QR standart yozuvda, maxsus belgilar ekranlanadi', () => {
  assert.equal(wifiQrPayload('Anor', 'choy-2026'), 'WIFI:T:WPA;S:Anor;P:choy-2026;;');
  assert.equal(wifiQrPayload('A;B', 'p:a"s\\s,'), 'WIFI:T:WPA;S:A\\;B;P:p\\:a\\"s\\\\s\\,;;');
  assert.equal(wifiQrPayload('Ochiq', null), 'WIFI:T:nopass;S:Ochiq;;');
});

test('F-03: faqat http va https havolalar sahifaga chiqadi', () => {
  assert.equal(safeHttpUrl('https://g.page/r/abc'), 'https://g.page/r/abc');
  assert.equal(safeHttpUrl('javascript:alert(1)'), null);
  assert.equal(safeHttpUrl('data:text/html,x'), null);
  assert.equal(safeHttpUrl('not a url'), null);
  assert.equal(safeHttpUrl(null), null);
});

test('B-08: telefon ocha olmaydigan manzil aniqlanadi', () => {
  assert.equal(isLocalOrigin('http://localhost:4173'), true);
  assert.equal(isLocalOrigin('http://127.0.0.1:4173'), true);
  assert.equal(isLocalOrigin('http://192.168.1.50:4173'), false);
  assert.equal(isLocalOrigin('https://tegio.uz'), false);
});
