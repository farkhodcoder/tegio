import { fail } from '@sveltejs/kit';
import { normalizeUzPhone } from '#lib/phone.ts';
import { backend } from '#lib/server/backend.ts';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async () => ({
  plans: await backend.getPlans(),
  bizUrl: process.env.BIZ_URL ?? 'https://biz.tegio.uz'
});

export const actions: Actions = {
  demo: async ({ request, getClientAddress }) => {
    const form = await request.formData();
    const name = String(form.get('name') ?? '').trim();
    const business_name = String(form.get('business_name') ?? '').trim();
    const phone = normalizeUzPhone(String(form.get('phone') ?? ''));
    if (!name || !phone) return fail(400, { demoError: true });
    await backend.requestDemo({ name, phone, business_name }, getClientAddress());
    return { demoDone: true };
  }
};
