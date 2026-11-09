import { error } from '@sveltejs/kit';
import { backend } from '#lib/server/backend.ts';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ params, url }) => {
  const cafe = await backend.getPage(params.slug, url.searchParams.get('t'));
  if (!cafe) error(404);
  return { cafe };
};
