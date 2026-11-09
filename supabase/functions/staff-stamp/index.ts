// POST /staff/stamp: kassir mehmon QR'ini skan qilgandan keyin (B-24, B-25, B-29).
import { verifyCardToken } from '../_shared/card_token.ts';
import { authenticatedUserId, corsHeaders, json, requireEnv, serviceClient } from '../_shared/http.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  if (req.method !== 'POST') return json({ ok: false, error: 'method_not_allowed' }, 405);

  const db = serviceClient();
  const userId = await authenticatedUserId(req, db);
  if (!userId) return json({ ok: false, error: 'unauthorized' }, 401);

  const { token, location_id, idempotency_key } = await req.json().catch(() => ({}));
  if (typeof token !== 'string' || typeof location_id !== 'string' || typeof idempotency_key !== 'string') {
    return json({ ok: false, error: 'bad_request' }, 400);
  }

  const verified = await verifyCardToken(token, requireEnv('CARD_TOKEN_SECRET'));
  if (!verified.ok) return json({ ok: false, error: verified.error });

  const { data, error } = await db.rpc('apply_stamp', {
    p_user_id: userId,
    p_membership_id: verified.payload.mid,
    p_location_id: location_id,
    p_jti: verified.payload.jti,
    p_idempotency_key: idempotency_key,
  });
  if (error) {
    console.error('apply_stamp failed', error.code);
    return json({ ok: false, error: 'server_error' }, 500);
  }
  return json(data);
});
