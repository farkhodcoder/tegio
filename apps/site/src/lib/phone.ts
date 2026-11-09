// O'zbekiston raqamini +998XXXXXXXXX shakliga keltiradi; noto'g'ri bo'lsa null.
export function normalizeUzPhone(raw: string): string | null {
  const digits = raw.replace(/\D/g, '');
  if (digits.length === 9) return `+998${digits}`;
  if (digits.length === 12 && digits.startsWith('998')) return `+${digits}`;
  return null;
}

export function maskPhone(phone: string): string {
  return `${phone.slice(0, 4)}•••••${phone.slice(-2)}`;
}
