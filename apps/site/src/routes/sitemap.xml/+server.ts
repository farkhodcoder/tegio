import type { RequestHandler } from './$types';

const PATHS = ['/', '/shartlar', '/maxfiylik'];

export const GET: RequestHandler = ({ url }) => {
  const urls = PATHS.map((path) => `<url><loc>${url.origin}${path}</loc></url>`).join('');
  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls}</urlset>`,
    { headers: { 'Content-Type': 'application/xml' } }
  );
};
