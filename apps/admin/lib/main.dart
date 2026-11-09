import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

import 'auth.dart';
import 'sections/businesses.dart';
import 'sections/content.dart';
import 'sections/dashboard.dart';
import 'sections/finance.dart';
import 'sections/security.dart';
import 'sections/support.dart';
import 'sections/tags.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initTegio();
  runApp(const TegioAdminApp());
}

class TegioAdminApp extends StatelessWidget {
  const TegioAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${TegioBrand.name} Admin',
      theme: tegioTheme(),
      debugShowCheckedModeBanner: false,
      home: StreamBuilder(
        stream: db.auth.onAuthStateChange,
        builder: (context, _) {
          if (db.auth.currentSession == null) return const LoginPage();
          final level = db.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel;
          return level?.name == 'aal2' ? const AdminHome() : const MfaPage();
        },
      ),
    );
  }
}

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  Future<Json?> _load() async {
    await db.rpc<dynamic>('admin_activate');
    return await db.rpc<dynamic>('admin_me') as Json?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadView<Json?>(
        load: _load,
        builder: (context, admin, _) {
          if (admin == null) return const NoAccessPage();
          ShellSection section(String label, IconData icon, Widget page) =>
              ShellSection(label: label, icon: icon, builder: (_) => page);
          return TegioShell(
            title: '${TegioBrand.name} Admin',
            actions: [IconButton(tooltip: 'Chiqish', onPressed: db.auth.signOut, icon: const Icon(Icons.logout))],
            sections: [
              section('Boshqaruv', Icons.space_dashboard_outlined, const DashboardSection()),
              section('Bizneslar', Icons.storefront_outlined, const BusinessesSection()),
              section('Tariflar va toʻlovlar', Icons.payments_outlined, const FinanceSection()),
              section('Yorliqlar', Icons.nfc, const TagsSection()),
              section('Yordam', Icons.support_agent, const SupportSection()),
              section('Kontent va sozlamalar', Icons.tune, const ContentSection()),
              if (admin['role'] == 'super_admin') section('Xavfsizlik', Icons.admin_panel_settings_outlined, const SecuritySection()),
            ],
          );
        },
      ),
    );
  }
}
