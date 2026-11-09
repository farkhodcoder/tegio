import { error, json } from '@sveltejs/kit';
import { renderSVG } from 'uqr';
import { backend, SESSION_COOKIE } from '#lib/server/backend.ts';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ url, cookies }) => {
  const session = cookies.get(SESSION_COOKIE);
  const slug = url.searchParams.get('slug');
  if (!session || !slug) error(401);

  const card = await backend.getCard(session, slug);
  if (!card) error(404);

  if (url.searchParams.get('qr') !== '1') return json({ card });

  const issued = await backend.issueCardToken(session, slug);
  if (!issued) error(404);
  return json({ card, qr: renderSVG(issued.token, { border: 2 }), expiresAt: issued.expiresAt });
};
