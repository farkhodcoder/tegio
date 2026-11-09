import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

class SecuritySection extends StatelessWidget {
  const SecuritySection({super.key});

  Future<void> _invite(BuildContext context, VoidCallback reload) async {
    final email = await askText(context, 'Taklif qilinadigan email', keyboard: TextInputType.emailAddress);
    if (email == null || email.isEmpty || !context.mounted) return;
    final role = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Rol'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'support'), child: const Text('Yordam xodimi')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'finance'), child: const Text('Moliyachi')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'super_admin'), child: const Text('Bosh admin')),
        ],
      ),
    );
    if (role == null || !context.mounted) return;
    await attempt(context, done: 'Taklif yuborildi', () async {
      final result = await callApi('/admin/invite', {'email': email, 'role': role});
      if (result['ok'] != true) throw const TegioApiException('invite_failed');
    });
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<(List<Json>, List<Json>)>(
      load: () async => (await rpcList('admin_list', {'p_kind': 'admins'}), await rpcList('admin_list', {'p_kind': 'audit'})),
      builder: (context, data, reload) {
        final (admins, audit) = data;
        return SectionList(
          children: [
            SectionTitle('Adminlar', trailing: TextButton(onPressed: () => _invite(context, reload), child: const Text('Taklif qilish'))),
            for (final admin in admins)
              ListTile(title: Text(admin['email'] as String), subtitle: Text('${admin['role']} · ${admin['status']}'), trailing: Icon(admin['totp_enabled'] == true ? Icons.verified_user : Icons.gpp_maybe_outlined)),
            const SectionTitle('Jurnal'),
            RowsTable(
              columns: const ['Vaqt', 'Amal', 'Obyekt'],
              rows: [for (final row in audit) [Text(formatDate(row['created_at'])), Text('${row['action']}'), Text('${row['entity']}')]],
            ),
          ],
        );
      },
    );
  }
}
