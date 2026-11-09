import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../setup.dart' show normalizePhone;
import '../state.dart';

const _roles = {'owner': 'Egasi', 'manager': 'Menejer', 'cashier': 'Kassir'};

class TeamSection extends StatelessWidget {
  const TeamSection({super.key});

  Future<(Json, Json)> _load() async {
    final team = await rpcJson('team_list', {'p_business_id': biz.id});
    final subscription = await rpcJson('subscription_state', {'p_business_id': biz.id});
    return (team, subscription);
  }

  Future<void> _invite(BuildContext context, VoidCallback reload) async {
    final result = await showDialog<(String, String)>(context: context, builder: (_) => const _InviteDialog());
    if (result == null || !context.mounted) return;
    await attempt(context, done: 'Taklif saqlandi. Xodim shu raqam bilan kirsin.', () async {
      await db.rpc<dynamic>('invite_staff', params: {
        'p_business_id': biz.id,
        'p_phone': result.$1,
        'p_role': result.$2,
        'p_location_id': null,
      });
    });
    reload();
  }

  Future<void> _pay(BuildContext context, String plan) async {
    final provider = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Toʻlov usuli'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'click'), child: const Text('Click')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'payme'), child: const Text('Payme')),
        ],
      ),
    );
    if (provider == null || !context.mounted) return;
    await attempt(context, () async {
      final result = await callApi('/biz/pay', {'business_id': biz.id, 'plan': plan, 'provider': provider});
      await launchUrl(Uri.parse(result['url'] as String));
    });
  }

  Future<void> _support(BuildContext context) async {
    final body = await askText(context, 'Yordam soʻrash', hint: 'Muammoni yozing', maxLines: 4);
    if (body == null || body.isEmpty || !context.mounted) return;
    await attempt(context, done: 'Murojaat yuborildi', () async {
      final subject = body.length > 60 ? body.substring(0, 60) : body;
      await db.from('support_tickets').insert({'business_id': biz.id, 'subject': subject, 'body': body});
    });
  }

  @override
  Widget build(BuildContext context) {
    return LoadView(
      load: _load,
      builder: (context, data, reload) {
        final (team, state) = data;
        final subscription = state['subscription'] as Json?;
        final end = DateTime.tryParse('${subscription?['period_end']}');
        final daysLeft = end?.difference(DateTime.now()).inDays;
        return SectionList(
          children: [
            SectionTitle('Jamoa', trailing: TextButton(onPressed: () => _invite(context, reload), child: const Text('Taklif qilish'))),
            for (final member in (team['members'] as List).cast<Json>())
              ListTile(
                title: Text('${member['phone']}'),
                subtitle: Text(_roles[member['role']] ?? '${member['role']}'),
                trailing: member['role'] == 'owner'
                    ? null
                    : IconButton(
                        tooltip: 'Olib tashlash',
                        icon: const Icon(Icons.person_remove_outlined),
                        onPressed: () => attempt(context, () async {
                          await db.rpc<dynamic>('remove_staff', params: {'p_business_id': biz.id, 'p_staff_id': member['id']});
                        }).then((_) => reload()),
                      ),
              ),
            for (final invite in (team['invites'] as List).cast<Json>())
              ListTile(title: Text('${invite['phone']}'), subtitle: Text('${_roles[invite['role']]} · kutilmoqda')),
            const SectionTitle('Obuna'),
            if (subscription != null)
              Card(
                child: ListTile(
                  title: Text('Tarif: ${subscription['plan']} (${subscription['status'] == 'trial' ? 'sinov' : subscription['status']})'),
                  subtitle: Text('Muddat: ${formatDate(subscription['period_end'])}'),
                  trailing: daysLeft != null && daysLeft <= 7 ? Chip(label: Text(daysLeft < 0 ? 'Muddat oʻtdi' : '$daysLeft kun qoldi')) : null,
                ),
              ),
            for (final plan in (state['plans'] as List).cast<Json>().where((plan) => (plan['price_uzs'] as int) > 0))
              ListTile(
                title: Text(plan['name'] as String),
                subtitle: Text('${formatMoney(plan['price_uzs'] as int)} / oy'),
                trailing: FilledButton(onPressed: () => _pay(context, plan['id'] as String), child: const Text('Toʻlash')),
              ),
            const SectionTitle('Toʻlovlar tarixi'),
            RowsTable(
              columns: const ['Sana', 'Summa', 'Usul', 'Holat'],
              rows: [
                for (final payment in (state['payments'] as List).cast<Json>())
                  [
                    Text(formatDate(payment['created_at'])),
                    Text(formatMoney(payment['amount_uzs'] as int)),
                    Text('${payment['provider']}'),
                    Text('${payment['status']}'),
                  ],
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () => _support(context), child: const Text('Yordam soʻrash')),
          ],
        );
      },
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _phone = TextEditingController();
  String _role = 'cashier';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Xodimni taklif qilish'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon raqami', prefixText: '+998 ')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            items: const [
              DropdownMenuItem(value: 'cashier', child: Text('Kassir')),
              DropdownMenuItem(value: 'manager', child: Text('Menejer')),
            ],
            onChanged: (value) => _role = value ?? 'cashier',
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
        FilledButton(
          onPressed: () {
            final phone = normalizePhone(_phone.text);
            if (phone.isNotEmpty) Navigator.pop(context, (phone, _role));
          },
          child: const Text('Taklif qilish'),
        ),
      ],
    );
  }
}
