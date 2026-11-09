import { redirect } from '@sveltejs/kit';
import { backend, SESSION_COOKIE } from '#lib/server/backend.ts';
import { sendOtpAction, verifyOtpAction } from '#lib/server/otp.ts';
import { isLocale, LOCALE_COOKIE } from '#lib/i18n.ts';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ cookies }) => {
  const session = cookies.get(SESSION_COOKIE);
  const profile = session ? await backend.getProfile(session) : null;
  if (!session || !profile) return { profile: null, cards: [], visits: [] };
  return { profile, cards: await backend.myCards(session), visits: await backend.visits(session) };
};

export const actions: Actions = {
  send: async ({ request }) => sendOtpAction(request),
  verify: async ({ request, cookies }) => verifyOtpAction(request, cookies),
  profile: async ({ request, cookies }) => {
    const session = cookies.get(SESSION_COOKIE);
    if (!session) return;
    const form = await request.formData();
    const locale = form.get('locale');
    if (!isLocale(locale)) return;
    await backend.updateProfile(session, { name: String(form.get('name') ?? '').trim().slice(0, 80), locale });
    cookies.set(LOCALE_COOKIE, locale, { path: '/', sameSite: 'lax', maxAge: 60 * 60 * 24 * 365, httpOnly: false });
    return { saved: true };
  },
  marketing: async ({ request, cookies }) => {
    const session = cookies.get(SESSION_COOKIE);
    if (!session) return;
    const form = await request.formData();
    await backend.setMarketing(session, String(form.get('membership_id')), form.get('consent') === 'on');
  },
  leave: async ({ request, cookies }) => {
    const session = cookies.get(SESSION_COOKIE);
    if (!session) return;
    const form = await request.formData();
    await backend.leaveProgram(session, String(form.get('membership_id')));
  },
  logout: async ({ cookies }) => {
    cookies.delete(SESSION_COOKIE, { path: '/' });
    redirect(303, '/me');
  },
  delete: async ({ cookies }) => {
    const session = cookies.get(SESSION_COOKIE);
    if (session) await backend.deleteAccount(session);
    cookies.delete(SESSION_COOKIE, { path: '/' });
    redirect(303, '/');
  }
};
