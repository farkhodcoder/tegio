// Kafe egasi kiritgan havolalar sahifaga shu orqali chiqadi: javascript: va shunga o'xshashlar o'tmaydi.
export function safeHttpUrl(value: string | null | undefined): string | null {
  if (!value) return null;
  try {
    const { protocol } = new URL(value);
    return protocol === 'https:' || protocol === 'http:' ? value : null;
  } catch {
    return null;
  }
}

export function tagUrl(origin: string, slug: string, code: string): string {
  return `${origin}/${encodeURIComponent(slug)}?t=${encodeURIComponent(code)}`;
}

export function isLocalOrigin(origin: string): boolean {
  const { hostname } = new URL(origin);
  return hostname === 'localhost' || hostname === '[::1]' || hostname.startsWith('127.');
}

// Telefon kameralari tushunadigan standart WIFI: yozuvi.
export function wifiQrPayload(ssid: string, password: string | null): string {
  const escape = (value: string) => value.replace(/[\\;,:"]/g, '\\$&');
  return password ? `WIFI:T:WPA;S:${escape(ssid)};P:${escape(password)};;` : `WIFI:T:nopass;S:${escape(ssid)};;`;
}
