// POST /staff/redeem: mukofotni ishlatish, ikkinchi urinish rad etiladi.
import { authenticatedUserId, corsHeaders, json, serviceClient } from '../_shared/http.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  if (req.method !== 'POST') return json({ ok: false, error: 'method_not_allowed' }, 405);

  const db = serviceClient();
  const userId = await authenticatedUserId(req, db);
  if (!userId) return json({ ok: false, error: 'unauthorized' }, 401);

  const { reward_id, location_id } = await req.json().catch(() => ({}));
  if (typeof reward_id !== 'string' || typeof location_id !== 'string') {
    return json({ ok: false, error: 'bad_request' }, 400);
  }

  const { data, error } = await db.rpc('redeem_reward', {
    p_user_id: userId,
    p_reward_id: reward_id,
    p_location_id: location_id,
  });
  if (error) {
    console.error('redeem_reward failed', error.code);
    return json({ ok: false, error: 'server_error' }, 500);
  }
  return json(data);
});
