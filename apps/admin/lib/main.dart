import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

void main() => runApp(const TegioAdminApp());

class TegioAdminApp extends StatelessWidget {
  const TegioAdminApp({super.key});

  static final _sections = [
    _pending('Boshqaruv', Icons.space_dashboard_outlined, 'P-01 – P-04'),
    _pending('Bizneslar', Icons.storefront_outlined, 'P-05 – P-10'),
    _pending('Tariflar va to\'lovlar', Icons.payments_outlined, 'P-11 – P-14'),
    _pending('Yorliqlar', Icons.nfc, 'P-16, P-17'),
    _pending('Yordam', Icons.support_agent, 'P-19 – P-21'),
    _pending('Kontent va sozlamalar', Icons.tune, 'P-22 – P-26'),
    _pending('Xavfsizlik', Icons.admin_panel_settings_outlined, 'P-27 – P-30'),
  ];

  static ShellSection _pending(String label, IconData icon, String requirements) => ShellSection(
    label: label,
    icon: icon,
    builder: (_) => SectionPending(requirements: requirements),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${TegioBrand.name} Admin',
      theme: tegioTheme(),
      debugShowCheckedModeBanner: false,
      home: TegioShell(title: '${TegioBrand.name} Admin', sections: _sections),
    );
  }
}
