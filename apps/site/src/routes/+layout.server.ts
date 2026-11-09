import { backend } from '#lib/server/backend.ts';
import { messages } from '#lib/server/messages.ts';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals }) => {
  const base = messages[locals.locale];
  const overrides = (await backend.getContent?.(locals.locale)) ?? {};
  return { locale: locals.locale, m: { ...base, ...overrides } as typeof base };
};
