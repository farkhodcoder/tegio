// config/brand.json dan yaratilgan. Qo'lda o'zgartirmang: pnpm sync:brand
import 'dart:ui' show Color;

abstract final class TegioBrand {
  static const String name = 'TEGIO';

  static const Color primary = Color(0xFFD63A0C);
  static const Color ink = Color(0xFF2B1510);
  static const Color muted = Color(0xFF7A564A);
  static const Color paper = Color(0xFFFFF4EC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFF5DACB);
  static const Color accent = Color(0xFF6C47FF);
  static const Color crust = Color(0xFFE8862A);
  static const Color dough = Color(0xFFFFD8A8);
  static const Color success = Color(0xFF1E7F4F);
  static const Color danger = Color(0xFFC62828);
}
