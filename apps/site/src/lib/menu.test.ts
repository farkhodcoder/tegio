import assert from 'node:assert/strict';
import { test } from 'node:test';
import { defaultMenuId, formatPrice, isScheduleActive, matchesFilters, matchesSearch, translate } from './menu.ts';
import type { PublicMenu } from './types.ts';

const TZ = 'Asia/Tashkent';
// 2026-11-09 dushanba. Toshkent UTC+5.
const at = (hhmm: string) => new Date(`2026-11-09T${hhmm}:00+05:00`);
const menu = (id: string, schedule: PublicMenu['schedule']): PublicMenu => ({ id, name: id, schedule, categories: [] });

test('M-04: oraliq filial vaqti bo\'yicha hisoblanadi', () => {
  const breakfast = { from: '07:00', to: '11:00' };
  assert.equal(isScheduleActive(breakfast, at('08:00'), TZ), true);
  assert.equal(isScheduleActive(breakfast, at('11:00'), TZ), false);
  assert.equal(isScheduleActive(breakfast, at('06:59'), TZ), false);
});

test('M-04: yarim tundan o\'tadigan jadval', () => {
  const late = { from: '22:00', to: '02:00' };
  assert.equal(isScheduleActive(late, at('23:30'), TZ), true);
  assert.equal(isScheduleActive(late, at('01:30'), TZ), true);
  assert.equal(isScheduleActive(late, at('12:00'), TZ), false);
});

test('M-04: hafta kunlari', () => {
  assert.equal(isScheduleActive({ days: [1], from: '00:00', to: '23:59' }, at('12:00'), TZ), true);
  assert.equal(isScheduleActive({ days: [6, 7], from: '00:00', to: '23:59' }, at('12:00'), TZ), false);
});

test('M-04: hozirgi jadvaldagi menyu ochiladi, bo\'lmasa jadvalsizi', () => {
  const menus = [menu('main', null), menu('breakfast', { from: '07:00', to: '11:00' })];
  assert.equal(defaultMenuId(menus, at('08:00'), TZ), 'breakfast');
  assert.equal(defaultMenuId(menus, at('15:00'), TZ), 'main');
  assert.equal(defaultMenuId([], at('15:00'), TZ), null);
});

test('M-05: tarjima yo\'q bo\'lsa o\'zbekchasi chiqadi', () => {
  const i18n = { 'name:uz': 'Osh', 'name:ru': 'Плов' };
  assert.equal(translate(i18n, 'name', 'ru'), 'Плов');
  assert.equal(translate(i18n, 'name', 'en'), 'Osh');
  assert.equal(translate(null, 'name', 'en'), '');
});

test('M-02: narx guruhlanadi', () => {
  assert.equal(formatPrice(45000), '45 000');
  assert.equal(formatPrice(900), '900');
  assert.equal(formatPrice(1250000), '1 250 000');
});

test('M-06: belgi talab qilinadi, allergen istisno qilinadi', () => {
  assert.equal(matchesFilters(['halal'], ['halal']), true);
  assert.equal(matchesFilters([], ['halal']), false);
  assert.equal(matchesFilters(['allergen:nuts'], ['no_nuts']), false);
  assert.equal(matchesFilters([], ['no_nuts']), true);
  assert.equal(matchesFilters(['halal', 'allergen:dairy'], ['halal', 'no_dairy']), false);
});

test('M-07: qidiruv katta-kichik harfni farqlamaydi', () => {
  assert.equal(matchesSearch(['Toshkent oshi'], 'OSH'), true);
  assert.equal(matchesSearch(['Плов'], 'пло'), true);
  assert.equal(matchesSearch(['Lag\'mon'], 'somsa'), false);
  assert.equal(matchesSearch(['Lag\'mon'], '   '), true);
});
