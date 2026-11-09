import type { Handle } from '@sveltejs/kit/hooks';
import { brandCss } from '#lib/brand.ts';
import { LOCALE_COOKIE, resolveLocale } from '#lib/i18n.ts';

const css = brandCss();

export const handle: Handle = async ({ event, resolve }) => {
  const locale = resolveLocale(event.cookies.get(LOCALE_COOKIE), event.request.headers.get('accept-language'));
  event.locals.locale = locale;
  return resolve(event, {
    transformPageChunk: ({ html }) => html.replace('%tegio.lang%', locale).replace('%tegio.brand%', css)
  });
};
