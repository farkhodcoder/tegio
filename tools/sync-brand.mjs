// config/brand.json dan Flutter ilovalari uchun Dart konstantalarini yaratadi.
// Sayt shu faylni to'g'ridan-to'g'ri o'qiydi, Flutter esa kompilyatsiyada qiymat talab qiladi.
import { readFileSync, writeFileSync } from 'node:fs';

const root = new URL('../', import.meta.url);
const brand = JSON.parse(readFileSync(new URL('config/brand.json', root), 'utf8'));

const colors = Object.entries(brand.colors)
  .map(([key, hex]) => `  static const Color ${key} = Color(0xFF${hex.slice(1).toUpperCase()});`)
  .join('\n');

writeFileSync(
  new URL('packages/tegio_core/lib/src/brand/brand.g.dart', root),
  `// config/brand.json dan yaratilgan. Qo'lda o'zgartirmang: pnpm sync:brand
import 'dart:ui' show Color;

abstract final class TegioBrand {
  static const String name = '${brand.name}';

${colors}
}
`,
);
