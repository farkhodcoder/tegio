import { messages } from '#lib/server/messages.ts';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = ({ locals }) => ({
  locale: locals.locale,
  m: messages[locals.locale]
});
