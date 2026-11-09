import { randomBytes } from 'node:crypto';
import { fail } from '@sveltejs/kit';
import { backend, DEVICE_COOKIE } from '#lib/server/backend.ts';
import type { Actions } from './$types';

export const actions: Actions = {
  default: async ({ request, params, cookies, url }) => {
    const form = await request.formData();
    const rating = Number(form.get('rating'));
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) return fail(400, { error: 'rating' });

    let device = cookies.get(DEVICE_COOKIE);
    if (!device) {
      device = randomBytes(16).toString('hex');
      cookies.set(DEVICE_COOKIE, device, { path: '/', httpOnly: true, sameSite: 'lax', maxAge: 60 * 60 * 24 * 365 });
    }

    const result = await backend.submitFeedback(params.slug, device, {
      rating,
      text: String(form.get('text') ?? '').slice(0, 2000),
      contact: String(form.get('contact') ?? '').slice(0, 200),
      tag: url.searchParams.get('t')
    });
    if (result === 'rate_limited') return fail(429, { error: 'limited' });
    return { sent: true };
  }
};
