// Kartaning shaxsiy QR tokeni: HMAC-SHA256 bilan imzolangan, 60 soniya amal qiladi (L-04).
// Bir martalikni bazadagi used_card_tokens ta'minlaydi; bu modul faqat imzo va muddatni tekshiradi.

export const CARD_TOKEN_TTL_SECONDS = 60;

export type CardTokenPayload = { mid: string; jti: string; exp: number };

export type VerifyResult =
  | { ok: true; payload: CardTokenPayload }
  | { ok: false; error: 'qr_invalid' | 'qr_expired' };

const encoder = new TextEncoder();

function toBase64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

function fromBase64Url(value: string): Uint8Array<ArrayBuffer> {
  const binary = atob(value.replaceAll('-', '+').replaceAll('_', '/'));
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function hmacKey(secret: string, usage: 'sign' | 'verify'): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    [usage],
  );
}

export async function signCardToken(
  membershipId: string,
  secret: string,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<{ token: string; expiresAt: number }> {
  const payload: CardTokenPayload = {
    mid: membershipId,
    jti: crypto.randomUUID(),
    exp: nowSeconds + CARD_TOKEN_TTL_SECONDS,
  };
  const body = toBase64Url(encoder.encode(JSON.stringify(payload)));
  const signature = await crypto.subtle.sign('HMAC', await hmacKey(secret, 'sign'), encoder.encode(body));
  return { token: `${body}.${toBase64Url(new Uint8Array(signature))}`, expiresAt: payload.exp };
}

export async function verifyCardToken(
  token: string,
  secret: string,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<VerifyResult> {
  const [body, signature, extra] = token.split('.');
  if (!body || !signature || extra !== undefined) return { ok: false, error: 'qr_invalid' };

  let payload: CardTokenPayload;
  try {
    // crypto.subtle.verify imzoni doimiy vaqtda solishtiradi.
    const valid = await crypto.subtle.verify(
      'HMAC',
      await hmacKey(secret, 'verify'),
      fromBase64Url(signature),
      encoder.encode(body),
    );
    if (!valid) return { ok: false, error: 'qr_invalid' };
    payload = JSON.parse(new TextDecoder().decode(fromBase64Url(body)));
  } catch {
    return { ok: false, error: 'qr_invalid' };
  }

  if (typeof payload.exp !== 'number' || payload.exp <= nowSeconds) {
    return { ok: false, error: 'qr_expired' };
  }
  return { ok: true, payload };
}
