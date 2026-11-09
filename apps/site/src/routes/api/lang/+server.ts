import { redirect } from '@sveltejs/kit';
import { isLocale, LOCALE_COOKIE } from '#lib/i18n.ts';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request, cookies }) => {
  const form = await request.formData();
  const locale = form.get('locale');
  const to = String(form.get('to') ?? '/');
  if (isLocale(locale)) {
    cookies.set(LOCALE_COOKIE, locale, { path: '/', sameSite: 'lax', maxAge: 60 * 60 * 24 * 365, httpOnly: false });
  }
  // Faqat o'z saytimiz ichiga qaytamiz (ochiq redirect bo'lmasin).
  redirect(303, to.startsWith('/') && !to.startsWith('//') && !to.startsWith('/\\') ? to : '/');
};
