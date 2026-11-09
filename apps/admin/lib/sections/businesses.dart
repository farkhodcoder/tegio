import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

const _statuses = {'active': 'Faol', 'payment_stopped': 'Toʻlov toʻxtagan', 'blocked': 'Bloklangan', 'hidden': 'Yashirilgan'};
const _demoStatuses = ['new', 'contacted', 'won', 'lost'];

class BusinessesSection extends StatelessWidget {
  const BusinessesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(tabs: [Tab(text: 'Bizneslar'), Tab(text: 'Demo soʻrovlar')]),
          Expanded(child: TabBarView(children: [_BusinessList(), _DemoList()])),
        ],
      ),
    );
  }
}

class _BusinessList extends StatefulWidget {
  const _BusinessList();

  @override
  State<_BusinessList> createState() => _BusinessListState();
}

class _BusinessListState extends State<_BusinessList> {
  final _search = TextEditingController();
  final _city = TextEditingController();
  String? _plan;
  String? _status;
  int _version = 0;

  String? _text(TextEditingController controller) => controller.text.trim().isEmpty ? null : controller.text.trim();

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Json>>(
      key: ValueKey(_version),
      load: () => rpcList('admin_businesses', {'p_q': _text(_search), 'p_city': _text(_city), 'p_plan': _plan, 'p_status': _status}),
      builder: (context, rows, reload) => SectionList(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 220, child: TextField(controller: _search, decoration: const InputDecoration(labelText: 'Qidiruv'), onSubmitted: (_) => setState(() => _version++))),
              SizedBox(width: 140, child: TextField(controller: _city, decoration: const InputDecoration(labelText: 'Shahar'), onSubmitted: (_) => setState(() => _version++))),
              DropdownButton<String?>(
                value: _plan,
                items: const [
                  DropdownMenuItem(child: Text('Barcha tariflar')),
                  DropdownMenuItem(value: 'free', child: Text('Bepul')),
                  DropdownMenuItem(value: 'start', child: Text('Start')),
                  DropdownMenuItem(value: 'pro', child: Text('Pro')),
                  DropdownMenuItem(value: 'network', child: Text('Tarmoq')),
                ],
                onChanged: (value) => setState(() {
                  _plan = value;
                  _version++;
                }),
              ),
              DropdownButton<String?>(
                value: _status,
                items: [
                  const DropdownMenuItem(child: Text('Barcha holatlar')),
                  for (final entry in _statuses.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (value) => setState(() {
                  _status = value;
                  _version++;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty) const Text('Biznes topilmadi.'),
          for (final row in rows)
            ListTile(
              title: Text(row['name'] as String),
              subtitle: Text('${row['slug']} · ${row['city'] ?? 'shahar yoʻq'} · ${row['plan']}'),
              trailing: Chip(label: Text(_statuses[row['status']] ?? '${row['status']}')),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _BusinessPage(row['id'] as String)));
                reload();
              },
            ),
        ],
      ),
    );
  }
}

/// Biznes kartochkasi. Har bir ochilish jurnalga yoziladi, mehmon raqamlari yashirin (P-06, P-08, P-09).
class _BusinessPage extends StatelessWidget {
  const _BusinessPage(this.id);

  final String id;

  Future<void> _setStatus(BuildContext context, VoidCallback reload) async {
    final status = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Yangi holat'),
        children: [for (final entry in _statuses.entries) SimpleDialogOption(onPressed: () => Navigator.pop(context, entry.key), child: Text(entry.value))],
      ),
    );
    if (status == null || !context.mounted) return;
    final reason = await askText(context, 'Sababi');
    if (reason == null || !context.mounted) return;
    await attempt(context, () async {
      await db.rpc<dynamic>('admin_set_business_status', params: {'p_id': id, 'p_status': status, 'p_reason': reason});
    });
    reload();
  }

  Future<void> _setPlan(BuildContext context, VoidCallback reload) async {
    final plan = await askText(context, 'Tarif id', hint: 'start, pro, network, free');
    if (plan == null || plan.isEmpty || !context.mounted) return;
    final days = int.tryParse(await askText(context, 'Necha kunga', initial: '30', keyboard: TextInputType.number) ?? '');
    if (days == null || !context.mounted) return;
    await attempt(context, () async {
      await db.rpc<dynamic>('admin_set_plan', params: {'p_id': id, 'p_plan': plan, 'p_days': days});
    });
    reload();
  }

  Future<void> _extend(BuildContext context, VoidCallback reload) async {
    final days = int.tryParse(await askText(context, 'Necha kunga uzaytirilsin', initial: '14', keyboard: TextInputType.number) ?? '');
    if (days == null || !context.mounted) return;
    await attempt(context, () async {
      await db.rpc<dynamic>('admin_extend_trial', params: {'p_id': id, 'p_days': days});
    });
    reload();
  }

  Future<void> _addPayment(BuildContext context, VoidCallback reload) async {
    final plan = await askText(context, 'Tarif id', hint: 'start, pro, network');
    if (plan == null || plan.isEmpty || !context.mounted) return;
    final amount = int.tryParse(await askText(context, 'Summa, soʻm', keyboard: TextInputType.number) ?? '');
    if (amount == null || !context.mounted) return;
    final provider = await askText(context, 'Usul', initial: 'cash', hint: 'cash yoki bank');
    if (provider == null || !context.mounted) return;
    final note = await askText(context, 'Izoh');
    if (note == null || !context.mounted) return;
    await attempt(context, () async {
      await db.rpc<dynamic>('admin_add_payment', params: {'p_id': id, 'p_plan': plan, 'p_amount': amount, 'p_provider': provider, 'p_note': note});
    });
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biznes')),
      body: LoadView<Json>(
        load: () => rpcJson('admin_business', {'p_id': id}),
        builder: (context, data, reload) {
          final business = data['business'] as Json;
          final subscription = data['subscription'] as Json?;
          return SectionList(
            children: [
              Text(business['name'] as String, style: Theme.of(context).textTheme.headlineSmall),
              Text('${business['slug']} · ${business['plan']} · ${_statuses[business['status']]}'),
              if (business['status_reason'] != null) Text('Sabab: ${business['status_reason']}'),
              if (subscription != null) Text('Obuna: ${subscription['status']}, ${formatDate(subscription['period_end'])} gacha'),
              Text('Faol aʼzolar: ${data['members']}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(onPressed: () => _setStatus(context, reload), child: const Text('Holatni oʻzgartirish')),
                  OutlinedButton(onPressed: () => _setPlan(context, reload), child: const Text('Tarif berish')),
                  OutlinedButton(onPressed: () => _extend(context, reload), child: const Text('Sinovni uzaytirish')),
                  OutlinedButton(onPressed: () => _addPayment(context, reload), child: const Text('Toʻlov kiritish')),
                ],
              ),
              const SectionTitle('Filiallar'),
              for (final location in (data['locations'] as List).cast<Json>()) ListTile(title: Text(location['name'] as String), subtitle: Text('${location['address'] ?? ''}')),
              const SectionTitle('Jamoa'),
              Text((data['team'] as List).cast<Json>().map((m) => '${m['role']} (${m['status']})').join(', ')),
              const SectionTitle('Mijozlar (dastlabki 50)'),
              RowsTable(columns: const ['Ism', 'Telefon'], rows: [for (final c in (data['customers'] as List).cast<Json>()) [Text('${c['name'] ?? '—'}'), Text('${c['phone']}')]]),
              const SectionTitle('Toʻlovlar'),
              RowsTable(
                columns: const ['Sana', 'Summa', 'Usul', 'Holat'],
                rows: [
                  for (final p in (data['payments'] as List).cast<Json>())
                    [Text(formatDate(p['created_at'])), Text(formatMoney(p['amount_uzs'] as num)), Text('${p['provider']}'), Text('${p['status']}')],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DemoList extends StatelessWidget {
  const _DemoList();

  Future<void> _note(BuildContext context, Json row, VoidCallback reload) async {
    final note = await askText(context, 'Izoh', initial: row['note'] as String? ?? '', maxLines: 3);
    if (note == null || !context.mounted) return;
    await _save(context, row, row['status'] as String, note, reload);
  }

  Future<void> _save(BuildContext context, Json row, String status, String? note, VoidCallback reload) async {
    await attempt(context, () async {
      await db.rpc<dynamic>('admin_update_demo', params: {'p_id': row['id'], 'p_status': status, 'p_note': note});
    });
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Json>>(
      load: () => rpcList('admin_list', {'p_kind': 'demo'}),
      builder: (context, rows, reload) => SectionList(
        children: [
          if (rows.isEmpty) const Text('Demo soʻrovlar yoʻq.'),
          for (final row in rows)
            ListTile(
              title: Text('${row['name']} · ${row['phone']}'),
              subtitle: Text('${row['business_name'] ?? ''}\n${row['note'] ?? ''}'),
              isThreeLine: true,
              onTap: () => _note(context, row, reload),
              trailing: DropdownButton<String>(
                value: row['status'] as String,
                items: [for (final status in _demoStatuses) DropdownMenuItem(value: status, child: Text(status))],
                onChanged: (status) => _save(context, row, status!, row['note'] as String?, reload),
              ),
            ),
        ],
      ),
    );
  }
}
