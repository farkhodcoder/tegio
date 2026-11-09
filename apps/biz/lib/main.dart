import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

void main() => runApp(const TegioBizApp());

class TegioBizApp extends StatelessWidget {
  const TegioBizApp({super.key});

  static final _sections = [
    _pending('Boshqaruv', Icons.space_dashboard_outlined, 'B-34, B-36'),
    _pending('Sahifa va yorliqlar', Icons.qr_code_2, 'B-05 – B-08'),
    _pending('Menyu', Icons.restaurant_menu, 'B-11 – B-15'),
    _pending('Sodiqlik', Icons.loyalty_outlined, 'B-17 – B-20'),
    _pending('Kassir', Icons.qr_code_scanner, 'B-23 – B-29'),
    _pending('Fikrlar', Icons.reviews_outlined, 'B-30 – B-32'),
    _pending('Mijozlar', Icons.people_outline, 'B-35, B-37'),
    _pending('Jamoa va obuna', Icons.settings_outlined, 'B-01 – B-04, B-39 – B-41'),
  ];

  static ShellSection _pending(String label, IconData icon, String requirements) => ShellSection(
    label: label,
    icon: icon,
    builder: (_) => SectionPending(requirements: requirements),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: TegioBrand.name,
      theme: tegioTheme(),
      debugShowCheckedModeBanner: false,
      home: TegioShell(title: TegioBrand.name, sections: _sections),
    );
  }
}
