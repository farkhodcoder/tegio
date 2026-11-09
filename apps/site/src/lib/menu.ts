import type { I18nMap, MenuSchedule, PublicMenu } from './types.ts';
import type { Locale } from './i18n.ts';

export function translate(i18n: I18nMap | null | undefined, field: string, locale: Locale): string {
  if (!i18n) return '';
  return i18n[`${field}:${locale}`] ?? i18n[`${field}:uz`] ?? '';
}

function localClock(now: Date, timeZone: string): { day: number; minutes: number } {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23'
  }).formatToParts(now);
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? '';
  const day = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].indexOf(get('weekday')) + 1;
  return { day, minutes: Number(get('hour')) * 60 + Number(get('minute')) };
}

function toMinutes(value: string): number {
  const [h, m] = value.split(':').map(Number);
  return h * 60 + m;
}

export function isScheduleActive(schedule: MenuSchedule | null, now: Date, timeZone: string): boolean {
  if (!schedule) return false;
  const { day, minutes } = localClock(now, timeZone);
  if (schedule.days && !schedule.days.includes(day)) return false;
  const from = toMinutes(schedule.from);
  const to = toMinutes(schedule.to);
  // Yarim tundan o'tadigan oraliq: masalan 22:00 dan 02:00 gacha.
  return from <= to ? minutes >= from && minutes < to : minutes >= from || minutes < to;
}

// Vaqtga qarab ochiladigan menyu (M-04): avval jadvali hozirga to'g'ri kelgani.
export function defaultMenuId(menus: PublicMenu[], now: Date, timeZone: string): string | null {
  const scheduled = menus.find((m) => isScheduleActive(m.schedule, now, timeZone));
  return (scheduled ?? menus.find((m) => !m.schedule) ?? menus[0])?.id ?? null;
}

export function formatPrice(priceUzs: number): string {
  return String(priceUzs).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
}

export type Filter = 'halal' | 'spicy' | 'vegetarian' | 'no_nuts' | 'no_dairy' | 'no_gluten';

const EXCLUDES: Partial<Record<Filter, string>> = {
  no_nuts: 'allergen:nuts',
  no_dairy: 'allergen:dairy',
  no_gluten: 'allergen:gluten'
};

export function matchesFilters(tags: string[], filters: Filter[]): boolean {
  return filters.every((filter) => {
    const excluded = EXCLUDES[filter];
    return excluded ? !tags.includes(excluded) : tags.includes(filter);
  });
}

export function matchesSearch(haystack: string[], query: string): boolean {
  const needle = query.trim().toLocaleLowerCase();
  return !needle || haystack.some((text) => text.toLocaleLowerCase().includes(needle));
}
