// B-08, W-02. Restoran tizimi tayyor bo'lguncha demo uchun.
import { error } from '@sveltejs/kit';
import { renderSVG } from 'uqr';
import { isLocalOrigin, tagUrl, wifiQrPayload } from '#lib/links.ts';
import { backend } from '#lib/server/backend.ts';
import type { PageServerLoad } from './$types';

const DEFAULT_TABLES = 8;
const MAX_TABLES = 40;

export const load: PageServerLoad = async ({ parent, url }) => {
  const { cafe } = await parent();
  if (cafe.status !== 'active' || !backend.demoTags) error(404);

  const requested = Number(url.searchParams.get('n') ?? DEFAULT_TABLES);
  const count = Number.isInteger(requested) ? Math.min(Math.max(requested, 1), MAX_TABLES) : DEFAULT_TABLES;
  const origin = process.env.TEGIO_PUBLIC_URL?.replace(/\/$/, '') || url.origin;

  const tags = (await backend.demoTags(cafe.slug, count)).map(({ code, table_label }) => {
    const link = tagUrl(origin, cafe.slug, code);
    return { code, table_label, link, qr: renderSVG(link, { ecc: 'Q', border: 4 }) };
  });

  const { wifi_ssid: ssid, wifi_password: password } = cafe.location;
  return {
    count,
    maxTables: MAX_TABLES,
    origin,
    localOnly: isLocalOrigin(origin),
    tags,
    wifiSsid: ssid,
    wifiQr: ssid ? renderSVG(wifiQrPayload(ssid, password), { ecc: 'M', border: 4 }) : null
  };
};
