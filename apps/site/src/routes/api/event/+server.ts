// Skan va tugma bosish (G-06). CDN keshidagi sahifadan alohida yuboriladi.
import { backend } from '#lib/server/backend.ts';
import type { RequestHandler } from './$types';

const ACTION = /^[a-z0-9_]{1,32}$/;

export const POST: RequestHandler = async ({ request }) => {
  const body = await request.json().catch(() => null);
  if (typeof body?.slug === 'string' && typeof body?.action === 'string' && ACTION.test(body.action)) {
    await backend.logEvent(body.slug, body.action, typeof body.tag === 'string' ? body.tag : null);
  }
  return new Response(null, { status: 204 });
};
