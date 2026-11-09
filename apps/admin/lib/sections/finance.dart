import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

class FinanceSection extends StatelessWidget {
  const FinanceSection({super.key});

  Future<void> _edit(BuildContext context, Json? plan, VoidCallback reload) async {
    await showDialog<void>(context: context, builder: (_) => _PlanDialog(plan));
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<(List<Json>, List<Json>)>(
      load: () async => (await rpcList('admin_list', {'p_kind': 'plans'}), await rpcList('admin_payments')),
      builder: (context, data, reload) {
        final (plans, payments) = data;
        return SectionList(
          children: [
            SectionTitle('Tariflar', trailing: TextButton(onPressed: () => _edit(context, null, reload), child: const Text('Yangi tarif'))),
            for (final plan in plans)
              ListTile(
                title: Text('${plan['name']} (${plan['id']})'),
                subtitle: Text(formatMoney(plan['price_uzs'] as num)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _edit(context, plan, reload),
              ),
            const SectionTitle('Toʻlovlar'),
            RowsTable(
              columns: const ['Sana', 'Biznes', 'Summa', 'Usul', 'Holat', 'Izoh'],
              rows: [
                for (final p in payments)
                  [
                    Text(formatDate(p['created_at'])),
                    Text('${p['business_name']}'),
                    Text(formatMoney(p['amount_uzs'] as num)),
                    Text('${p['provider']}'),
                    Text('${p['status']}'),
                    Text('${p['note'] ?? ''}'),
                  ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PlanDialog extends StatefulWidget {
  const _PlanDialog(this.plan);

  final Json? plan;

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  late final _id = TextEditingController(text: widget.plan?['id'] as String? ?? '');
  late final _name = TextEditingController(text: widget.plan?['name'] as String? ?? '');
  late final _price = TextEditingController(text: '${widget.plan?['price_uzs'] ?? ''}');
  late final _limits = TextEditingController(text: jsonEncode(widget.plan?['limits_json'] ?? {'locations': 1}));
  late final _modules = TextEditingController(text: jsonEncode(widget.plan?['modules_json'] ?? {'menu': true}));

  Future<void> _save() async {
    final price = int.tryParse(_price.text);
    final Object? limits;
    final Object? modules;
    try {
      limits = jsonDecode(_limits.text);
      modules = jsonDecode(_modules.text);
    } on FormatException {
      showMessage(context, 'Limit va modullar JSON koʻrinishida boʻlsin.');
      return;
    }
    if (_id.text.trim().isEmpty || _name.text.trim().isEmpty || price == null || price < 0) {
      showMessage(context, 'Id, nom va narxni kiriting.');
      return;
    }
    final navigator = Navigator.of(context);
    final saved = await attempt(context, () async {
      await db.rpc<dynamic>('admin_save_plan', params: {
        'p_id': _id.text.trim(),
        'p_name': _name.text.trim(),
        'p_price': price,
        'p_limits': limits,
        'p_modules': modules,
      });
    });
    if (saved) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tarif'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _id, enabled: widget.plan == null, decoration: const InputDecoration(labelText: 'Id')),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nomi')),
            TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Narx, soʻm')),
            TextField(controller: _limits, decoration: const InputDecoration(labelText: 'Limitlar (JSON)')),
            TextField(controller: _modules, maxLines: 3, decoration: const InputDecoration(labelText: 'Modullar (JSON)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
        FilledButton(onPressed: _save, child: const Text('Saqlash')),
      ],
    );
  }
}
