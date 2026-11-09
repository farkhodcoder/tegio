// Brend faqat config/brand.json da turadi: logotip yoki rang almashsa, kod o'zgarmaydi.
import brand from '../../../../config/brand.json' with { type: 'json' };

export { brand };

function luminance(hex: string): number {
  const channels = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
  const [r, g, b] = channels.map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

// Biznes rangi ustidagi matn WCAG AA kontrastini saqlashi uchun.
export function readableOn(hex: string): string {
  return luminance(hex) > 0.179 ? brand.colors.ink : '#FFFFFF';
}

export function isHexColor(value: unknown): value is string {
  return typeof value === 'string' && /^#[0-9a-fA-F]{6}$/.test(value);
}

export function brandCss(): string {
  const vars = Object.entries(brand.colors).map(([key, value]) => `--${key}:${value}`);
  return `:root{${vars.join(';')};--on-primary:${readableOn(brand.colors.primary)}}`;
}
