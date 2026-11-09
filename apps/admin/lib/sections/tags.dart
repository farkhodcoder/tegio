import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

class TagsSection extends StatelessWidget {
  const TagsSection({super.key});

  Future<void> _createBatch(BuildContext context, VoidCallback reload) async {
    final type = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Yorliq turi'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'qr'), child: const Text('QR')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'nfc'), child: const Text('NFC')),
        ],
      ),
    );
    if (type == null || !context.mounted) return;
    final quantity = int.tryParse(await askText(context, 'Nechta (1–2000)', initial: '100', keyboard: TextInputType.number) ?? '');
    if (quantity == null || !context.mounted) return;
    await attempt(context, () async {
      final codes = await db.rpc<dynamic>('admin_create_batch', params: {'p_type': type, 'p_quantity': quantity}) as List;
      downloadCsv('tegio-partiya.csv', [
        ['Kod', 'Tur'],
        for (final code in codes) [code, type],
      ]);
    });
    reload();
  }

  Future<void> _assign(BuildContext context, String? code, VoidCallback reload) async {
    await showDialog<void>(context: context, builder: (_) => _AssignDialog(code));
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<(List<Json>, List<Json>)>(
      load: () async => (await rpcList('admin_list', {'p_kind': 'batches'}), await rpcList('admin_list', {'p_kind': 'tags'})),
      builder: (context, data, reload) {
        final (batches, tags) = data;
        return SectionList(
          children: [
            SectionTitle('Partiyalar', trailing: TextButton(onPressed: () => _createBatch(context, reload), child: const Text('Yangi partiya'))),
            RowsTable(
              columns: const ['Sana', 'Tur', 'Soni'],
              rows: [for (final b in batches) [Text(formatDate(b['created_at'])), Text('${b['type']}'), Text('${b['quantity']}')]],
            ),
            SectionTitle('Yorliqlar', trailing: TextButton(onPressed: () => _assign(context, null, reload), child: const Text('Biriktirish'))),
            RowsTable(
              columns: const ['Kod', 'Tur', 'Stol', 'Holat', ''],
              rows: [
                for (final tag in tags)
                  [
                    Text('${tag['code']}'),
                    Text('${tag['type']}'),
                    Text('${tag['table_label'] ?? '—'}'),
                    Text(tag['business_id'] == null ? 'Boʻsh' : 'Biriktirilgan'),
                    TextButton(onPressed: () => _assign(context, tag['code'] as String, reload), child: const Text('Biriktirish')),
                  ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AssignDialog extends StatefulWidget {
  const _AssignDialog(this.code);

  final String? code;

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  late final _code = TextEditingController(text: widget.code ?? '');
  final _label = TextEditingController();
  final Future<List<Json>> _businesses = rpcList('admin_businesses', {'p_q': null, 'p_city': null, 'p_plan': null, 'p_status': null});
  String? _business;
  String? _location;
  List<Json> _locations = const [];

  Future<void> _pickBusiness(String? id) async {
    setState(() {
      _business = id;
      _location = null;
      _locations = const [];
    });
    if (id == null) return;
    await attempt(context, () async {
      final detail = await rpcJson('admin_business', {'p_id': id});
      setState(() => _locations = (detail['locations'] as List).cast<Json>());
    });
  }

  Future<void> _save() async {
    if (_code.text.trim().isEmpty || _business == null || _location == null) {
      showMessage(context, 'Kod, biznes va filialni tanlang.');
      return;
    }
    final navigator = Navigator.of(context);
    final saved = await attempt(context, () async {
      await db.rpc<dynamic>('admin_assign_tag', params: {
        'p_code': _code.text.trim(),
        'p_business': _business,
        'p_location': _location,
        'p_label': _label.text.trim().isEmpty ? null : _label.text.trim(),
      });
    });
    if (saved) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yorliqni biriktirish'),
      content: SizedBox(
        width: 400,
        child: FutureBuilder<List<Json>>(
          future: _businesses,
          builder: (context, snapshot) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _code, decoration: const InputDecoration(labelText: 'Kod')),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Biznes'),
                items: [for (final b in snapshot.data ?? const <Json>[]) DropdownMenuItem(value: b['id'] as String, child: Text(b['name'] as String))],
                onChanged: _pickBusiness,
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(_business),
                decoration: const InputDecoration(labelText: 'Filial'),
                items: [for (final l in _locations) DropdownMenuItem(value: l['id'] as String, child: Text(l['name'] as String))],
                onChanged: (value) => _location = value,
              ),
              TextField(controller: _label, decoration: const InputDecoration(labelText: 'Stol')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
        FilledButton(onPressed: _save, child: const Text('Saqlash')),
      ],
    );
  }
}
