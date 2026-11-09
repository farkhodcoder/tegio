// config/brand.json dan yaratilgan. Qo'lda o'zgartirmang: pnpm sync:brand
import 'dart:ui' show Color;

abstract final class TegioBrand {
  static const String name = 'TEGIO';

  static const Color primary = Color(0xFF1D3FA8);
  static const Color ink = Color(0xFF101A38);
  static const Color muted = Color(0xFF515C7A);
  static const Color paper = Color(0xFFF2F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFD8E0EC);
  static const Color accent = Color(0xFF0B7A7A);
  static const Color crust = Color(0xFFC8892E);
  static const Color dough = Color(0xFFEFD3A0);
  static const Color success = Color(0xFF1F7A4D);
  static const Color danger = Color(0xFFB3261E);
}
