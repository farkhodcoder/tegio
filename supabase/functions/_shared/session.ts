// Mehmon sessiyasi: HMAC bilan imzolangan, 90 kun amal qiladi. Sayt uni httpOnly cookie'da saqlaydi.
export type GuestSession = { uid: string; phone: string; exp: number };

export const SESSION_TTL_SECONDS = 60 * 60 * 24 * 90;

const encoder = new TextEncoder();
const b64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
const fromB64url = (value: string) =>
  Uint8Array.from(atob(value.replaceAll('-', '+').replaceAll('_', '/')), (c) => c.charCodeAt(0));

const key = (secret: string, usage: 'sign' | 'verify') =>
  crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, [usage]);

export async function signSession(
  uid: string,
  phone: string,
  secret: string,
  now = Math.floor(Date.now() / 1000),
): Promise<string> {
  const body = b64url(encoder.encode(JSON.stringify({ uid, phone, exp: now + SESSION_TTL_SECONDS })));
  const signature = await crypto.subtle.sign('HMAC', await key(secret, 'sign'), encoder.encode(body));
  return `${body}.${b64url(new Uint8Array(signature))}`;
}

export async function verifySession(
  token: string | null,
  secret: string,
  now = Math.floor(Date.now() / 1000),
): Promise<GuestSession | null> {
  if (!token) return null;
  const [body, signature, extra] = token.split('.');
  if (!body || !signature || extra !== undefined) return null;
  try {
    const valid = await crypto.subtle.verify('HMAC', await key(secret, 'verify'), fromB64url(signature), encoder.encode(body));
    if (!valid) return null;
    const session: GuestSession = JSON.parse(new TextDecoder().decode(fromB64url(body)));
    return session.exp > now ? session : null;
  } catch {
    return null;
  }
}
