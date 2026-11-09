import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

const _locales = ['uz', 'uz-Cyrl', 'ru', 'en'];

class ContentSection extends StatelessWidget {
  const ContentSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(isScrollable: true, tabs: [Tab(text: 'Sayt matnlari'), Tab(text: 'Shablonlar'), Tab(text: 'Modullar'), Tab(text: 'Xarajat')]),
          Expanded(child: TabBarView(children: [_SiteContent(), _Templates(), _Flags(), _Usage()])),
        ],
      ),
    );
  }
}

class _TextEntry {
  const _TextEntry(this.key, this.locale, this.value, this.channel);

  final String key;
  final String locale;
  final String value;
  final String channel;
}

Future<_TextEntry?> _editEntry(BuildContext context, {Json? row, String valueField = 'value', bool channel = false}) {
  final key = TextEditingController(text: row?['key'] as String? ?? '');
  final value = TextEditingController(text: row?[valueField] as String? ?? '');
  var locale = row?['locale'] as String? ?? 'uz';
  var selectedChannel = row?['channel'] as String? ?? 'sms';
  return showDialog<_TextEntry>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Matn'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: key, enabled: row == null, decoration: const InputDecoration(labelText: 'Kalit')),
            DropdownButtonFormField<String>(
              initialValue: locale,
              decoration: const InputDecoration(labelText: 'Til'),
              items: [for (final item in _locales) DropdownMenuItem(value: item, child: Text(item))],
              onChanged: row == null ? (item) => locale = item ?? locale : null,
            ),
            if (channel)
              DropdownButtonFormField<String>(
                initialValue: selectedChannel,
                decoration: const InputDecoration(labelText: 'Kanal'),
                items: const [DropdownMenuItem(value: 'sms', child: Text('SMS')), DropdownMenuItem(value: 'telegram', child: Text('Telegram'))],
                onChanged: row == null ? (item) => selectedChannel = item ?? selectedChannel : null,
              ),
            TextField(controller: value, maxLines: 4, decoration: const InputDecoration(labelText: 'Matn')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
        FilledButton(
          onPressed: () {
            if (key.text.trim().isEmpty || value.text.trim().isEmpty) return;
            Navigator.pop(context, _TextEntry(key.text.trim(), locale, value.text.trim(), selectedChannel));
          },
          child: const Text('Saqlash'),
        ),
      ],
    ),
  );
}

/// Kalit saytdagi matn kaliti bilan bir xil bo'lsa, bazadagi matn o'sha joyda ko'rinadi (S-06, P-22).
class _SiteContent extends StatelessWidget {
  const _SiteContent();

  Future<void> _edit(BuildContext context, Json? row, VoidCallback reload) async {
    final entry = await _editEntry(context, row: row);
    if (entry == null || !context.mounted) return;
    await attempt(context, () async {
      await db.rpc<dynamic>('admin_save_content', params: {'p_key': entry.key, 'p_locale': entry.locale, 'p_value': entry.value});
    });
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Json>>(
      load: () => rpcList('admin_list', {'p_kind': 'content'}),
      builder: (context, rows, reload) => SectionList(
        children: [
          SectionTitle('Saytdagi matnni almashtirish', trailing: TextButton(onPressed: () => _edit(context, null, reload), child: const Text('Qoʻshish'))),
          for (final row in rows)
            ListTile(title: Text('${row['key']} · ${row['locale']}'), subtitle: Text(row['value'] as String), onTap: () => _edit(context, row, reload)),
        ],
      ),
    );
  }
}

class _Templates extends StatelessWidget {
  const _Templates();

  Future<void> _edit(BuildContext context, Json? row, VoidCallback reload) async {
    final entry = await _editEntry(context, row: row, valueField: 'body', channel: true);
    if (entry == null || !context.mounted) return;
    await attempt(context, () async {
      await db.rpc<dynamic>('admin_save_template', params: {'p_key': entry.key, 'p_channel': entry.channel, 'p_locale': entry.locale, 'p_body': entry.value});
    });
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Json>>(
      load: () => rpcList('admin_list', {'p_kind': 'templates'}),
      builder: (context, rows, reload) => SectionList(
        children: [
          SectionTitle('SMS va Telegram', trailing: TextButton(onPressed: () => _edit(context, null, reload), child: const Text('Qoʻshish'))),
          for (final row in rows)
            ListTile(title: Text('${row['key']} · ${row['channel']} · ${row['locale']}'), subtitle: Text(row['body'] as String), onTap: () => _edit(context, row, reload)),
        ],
      ),
    );
  }
}

class _Flags extends StatelessWidget {
  const _Flags();

  Future<void> _set(BuildContext context, String key, String? business, bool enabled, VoidCallback reload) async {
    await attempt(context, () async {
      await db.rpc<dynamic>('admin_set_flag', params: {'p_key': key, 'p_business': business, 'p_enabled': enabled});
    });
    reload();
  }

  Future<void> _add(BuildContext context, VoidCallback reload) async {
    final key = await askText(context, 'Modul kaliti', hint: 'ai');
    if (key == null || key.isEmpty || !context.mounted) return;
    final business = await askText(context, 'Biznes id', hint: 'Global uchun boʻsh qoldiring');
    if (business == null || !context.mounted) return;
    await _set(context, key, business.isEmpty ? null : business, true, reload);
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Json>>(
      load: () => rpcList('admin_list', {'p_kind': 'flags'}),
      builder: (context, rows, reload) => SectionList(
        children: [
          SectionTitle('Modullar', trailing: TextButton(onPressed: () => _add(context, reload), child: const Text('Qoʻshish'))),
          for (final row in rows)
            SwitchListTile(
              title: Text(row['key'] as String),
              subtitle: Text(row['business_id'] == null ? 'Global' : '${row['business_id']}'),
              value: row['enabled'] as bool,
              onChanged: (value) => _set(context, row['key'] as String, row['business_id'] as String?, value, reload),
            ),
        ],
      ),
    );
  }
}

class _Usage extends StatelessWidget {
  const _Usage();

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Json>>(
      load: () => rpcList('admin_list', {'p_kind': 'usage'}),
      builder: (context, rows, _) => SectionList(
        children: [
          const SectionTitle('Bu oy: AI va SMS'),
          RowsTable(
            columns: const ['Biznes', 'Tur', 'Soni', 'Xarajat'],
            rows: [
              for (final row in rows)
                [Text('${row['business'] ?? 'Tizim'}'), Text('${row['kind']}'), Text('${row['count']}'), Text(formatMoney(row['cost_uzs'] as num?))],
            ],
          ),
        ],
      ),
    );
  }
}
