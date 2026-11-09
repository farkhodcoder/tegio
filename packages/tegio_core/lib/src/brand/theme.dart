import 'package:flutter/material.dart';

import 'brand.g.dart';

ThemeData tegioTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: TegioBrand.primary,
    primary: TegioBrand.primary,
    surface: TegioBrand.surface,
    error: TegioBrand.danger,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: TegioBrand.paper,
    dividerColor: TegioBrand.line,
  );
}
