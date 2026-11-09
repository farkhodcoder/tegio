import { fail } from '@sveltejs/kit';
import { backend, SESSION_COOKIE } from '#lib/server/backend.ts';
import { sendOtpAction, verifyOtpAction } from '#lib/server/otp.ts';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ cookies, params }) => {
  const session = cookies.get(SESSION_COOKIE);
  const profile = session ? await backend.getProfile(session) : null;
  const card = session && profile ? await backend.getCard(session, params.slug) : null;
  return { signedIn: !!profile, card, demo: backend.demo };
};

export const actions: Actions = {
  send: async ({ request, getClientAddress }) => sendOtpAction(request, getClientAddress()),
  verify: async ({ request, cookies }) => verifyOtpAction(request, cookies),
  join: async ({ request, cookies, params }) => {
    const session = cookies.get(SESSION_COOKIE);
    if (!session) return fail(401, { joinError: 'session' });
    const form = await request.formData();
    if (form.get('terms') !== 'on') return fail(400, { joinError: 'terms' });
    const joined = await backend.join(session, params.slug, {
      name: String(form.get('name') ?? '').trim().slice(0, 80),
      terms: true,
      marketing: form.get('marketing') === 'on'
    });
    return joined ? { joined: true } : fail(400, { joinError: 'session' });
  },
  demoStamp: async ({ cookies, params }) => {
    const session = cookies.get(SESSION_COOKIE);
    if (session) await backend.demoStamp?.(session, params.slug);
    return { stamped: true };
  }
};
