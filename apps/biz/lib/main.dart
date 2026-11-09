import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

import 'sections/cashier.dart';
import 'sections/customers.dart';
import 'sections/dashboard.dart';
import 'sections/feedback.dart';
import 'sections/loyalty.dart';
import 'sections/menu.dart';
import 'sections/page_setup.dart';
import 'sections/team.dart';
import 'setup.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initTegio();
  runApp(const TegioBizApp());
}

class TegioBizApp extends StatelessWidget {
  const TegioBizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: TegioBrand.name,
      theme: tegioTheme(),
      debugShowCheckedModeBanner: false,
      home: StreamBuilder(
        stream: db.auth.onAuthStateChange,
        builder: (context, _) => db.auth.currentSession == null ? const LoginPage() : const BizHome(),
      ),
    );
  }
}

class BizHome extends StatelessWidget {
  const BizHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadView<void>(
        load: biz.load,
        builder: (context, _, _) => ListenableBuilder(
          listenable: biz,
          builder: (context, _) {
            if (biz.businesses.isEmpty) return const CreateBusinessPage();
            return TegioShell(
              key: ValueKey('${biz.id}:${biz.locationId}'),
              title: biz.business['name'] as String,
              sections: _sections(),
              actions: const [_ContextSwitcher()],
            );
          },
        ),
      ),
    );
  }

  List<ShellSection> _sections() {
    ShellSection section(String label, IconData icon, Widget page) =>
        ShellSection(label: label, icon: icon, builder: (_) => page);
    final cashier = section('Kassir', Icons.qr_code_scanner, const CashierSection());
    if (!biz.canManage) return [cashier];
    return [
      section('Boshqaruv', Icons.space_dashboard_outlined, const DashboardSection()),
      section('Sahifa va yorliqlar', Icons.qr_code_2, const PageSetupSection()),
      section('Menyu', Icons.restaurant_menu, const MenuSection()),
      section('Sodiqlik', Icons.loyalty_outlined, const LoyaltySection()),
      cashier,
      section('Fikrlar', Icons.reviews_outlined, const FeedbackSection()),
      section('Mijozlar', Icons.people_outline, const CustomersSection()),
      if (biz.isOwner) section('Jamoa va obuna', Icons.settings_outlined, const TeamSection()),
    ];
  }
}

/// Bir hisobda bir nechta biznes va filial orasida tez o'tish (B-02).
class _ContextSwitcher extends StatelessWidget {
  const _ContextSwitcher();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Biznes va filial',
      icon: const Icon(Icons.storefront_outlined),
      onSelected: (value) async {
        if (value == 'logout') {
          await db.auth.signOut();
        } else if (value == 'new') {
          await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CreateBusinessPage()));
        } else if (value.startsWith('b:')) {
          biz.selectBusiness(value.substring(2));
        } else if (value.startsWith('l:')) {
          biz.selectLocation(value.substring(2));
        }
      },
      itemBuilder: (context) => [
        for (final b in biz.businesses)
          CheckedPopupMenuItem(value: 'b:${b['id']}', checked: b['id'] == biz.id, child: Text(b['name'] as String)),
        const PopupMenuDivider(),
        for (final l in biz.locations)
          CheckedPopupMenuItem(value: 'l:${l['id']}', checked: l['id'] == biz.locationId, child: Text(l['name'] as String)),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'new', child: Text('Yangi biznes')),
        const PopupMenuItem(value: 'logout', child: Text('Chiqish')),
      ],
    );
  }
}
