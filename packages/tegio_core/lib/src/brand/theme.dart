import 'package:flutter/material.dart';

import 'brand.g.dart';

/// Iliq, quvnoq ko'rinish: yumaloq burchaklar, "pill" tugmalar, yumshoq soyalar.
ThemeData tegioTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: TegioBrand.primary,
    primary: TegioBrand.primary,
    onPrimary: Colors.white,
    secondary: TegioBrand.accent,
    tertiary: TegioBrand.crust,
    surface: TegioBrand.surface,
    onSurface: TegioBrand.ink,
    error: TegioBrand.danger,
  );
  const pill = StadiumBorder();
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(22));
  final field = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: TegioBrand.line, width: 1.5),
  );
  const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 14);

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: TegioBrand.paper,
    dividerColor: TegioBrand.line,
    appBarTheme: const AppBarTheme(
      backgroundColor: TegioBrand.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: TegioBrand.surface,
      elevation: 0,
      shape: rounded.copyWith(side: const BorderSide(color: TegioBrand.line)),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: pill, padding: buttonPadding, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: pill, padding: buttonPadding),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        padding: buttonPadding,
        side: const BorderSide(color: TegioBrand.primary, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: pill)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: TegioBrand.primary,
      foregroundColor: Colors.white,
      shape: StadiumBorder(),
    ),
    chipTheme: const ChipThemeData(shape: StadiumBorder(), side: BorderSide(color: TegioBrand.line)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TegioBrand.surface,
      border: field,
      enabledBorder: field,
      focusedBorder: field.copyWith(borderSide: const BorderSide(color: TegioBrand.primary, width: 2)),
    ),
    dialogTheme: DialogThemeData(shape: rounded),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: TegioBrand.paper,
      indicatorColor: TegioBrand.dough,
      indicatorShape: pill,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: TegioBrand.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
