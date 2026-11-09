export const LOCALES = ['uz', 'uz-Cyrl', 'ru', 'en'] as const;
export type Locale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: Locale = 'uz';
export const LOCALE_COOKIE = 'tegio_locale';

export const LOCALE_LABELS: Record<Locale, string> = {
  uz: 'Oʻz',
  'uz-Cyrl': 'Ўз',
  ru: 'Ру',
  en: 'En'
};

export function isLocale(value: unknown): value is Locale {
  return LOCALES.includes(value as Locale);
}

// Avval qo'lda tanlangan til, keyin telefon sozlamasi (G-05).
export function resolveLocale(cookie: string | undefined, acceptLanguage: string | null): Locale {
  if (isLocale(cookie)) return cookie;
  for (const part of (acceptLanguage ?? '').split(',')) {
    const tag = part.split(';')[0].trim().toLowerCase();
    if (tag.startsWith('uz-cyrl')) return 'uz-Cyrl';
    if (tag.startsWith('uz')) return 'uz';
    if (tag.startsWith('ru')) return 'ru';
    if (tag.startsWith('en')) return 'en';
  }
  return DEFAULT_LOCALE;
}

export function fmt(template: string, params: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (_, key) => String(params[key] ?? ''));
}
