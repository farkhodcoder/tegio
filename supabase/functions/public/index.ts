// GET /public/{slug}?t={yorliq}: sahifa va menyu, CDN keshida (G-01, B-12).
import { corsHeaders, json, requireEnv, serviceClient } from '../_shared/http.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  if (req.method !== 'GET') return json({ error: 'method_not_allowed' }, 405);

  const url = new URL(req.url);
  const slug = url.pathname.split('/').filter(Boolean).at(-1);
  if (!slug) return json({ error: 'not_found' }, 404);

  const { data, error } = await serviceClient().rpc('public_page', {
    p_slug: slug,
    p_tag_code: url.searchParams.get('t'),
    p_wifi_key: requireEnv('WIFI_ENCRYPTION_KEY'),
  });
  if (error) {
    console.error('public_page failed', error.code);
    return json({ error: 'server_error' }, 500);
  }
  if (!data) return json({ error: 'not_found' }, 404);

  // 60 soniya: narx o'zgarishi shu vaqt ichida ko'rinadi (B-12).
  return json(data, 200, { 'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=30' });
});
