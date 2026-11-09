import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

class SupportSection extends StatelessWidget {
  const SupportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(tabs: [Tab(text: 'Murojaatlar'), Tab(text: 'Shikoyatlar'), Tab(text: 'Oʻchirish')]),
          Expanded(child: TabBarView(children: [_Tickets(), _Reports(), _Deletions()])),
        ],
      ),
    );
  }
}

Widget _adminList(String kind, Widget Function(BuildContext, Json, VoidCallback) tile) {
  return LoadView<List<Json>>(
    load: () => rpcList('admin_list', {'p_kind': kind}),
    builder: (context, rows, reload) => SectionList(
      children: [
        if (rows.isEmpty) const Text('Hozircha yoʻq.'),
        for (final row in rows) tile(context, row, reload),
      ],
    ),
  );
}

class _Tickets extends StatelessWidget {
  const _Tickets();

  Future<void> _reply(BuildContext context, Json row, VoidCallback reload) async {
    final reply = await askText(context, 'Javob', initial: row['reply'] as String? ?? '', maxLines: 4);
    if (reply == null || !context.mounted) return;
    await attempt(context, () async {
      await db.rpc<dynamic>('admin_update_ticket', params: {'p_id': row['id'], 'p_status': 'closed', 'p_reply': reply});
    });
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return _adminList('tickets', (context, row, reload) => ListTile(
      title: Text(row['subject'] as String),
      subtitle: Text('${row['body'] ?? ''}\n${row['reply'] == null ? '' : 'Javob: ${row['reply']}'}'),
      isThreeLine: true,
      trailing: Chip(label: Text('${row['status']}')),
      onTap: () => _reply(context, row, reload),
    ));
  }
}

class _Reports extends StatelessWidget {
  const _Reports();

  Future<void> _resolve(BuildContext context, Json row, String status, bool hide, VoidCallback reload) async {
    await attempt(context, () async {
      await db.rpc<dynamic>('admin_resolve_report', params: {'p_id': row['id'], 'p_status': status, 'p_hide': hide});
    });
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return _adminList('reports', (context, row, reload) => ListTile(
      title: Text(row['reason'] as String),
      subtitle: Text('${row['status']} · ${formatDate(row['created_at'])}'),
      trailing: row['status'] != 'open'
          ? null
          : Wrap(
              spacing: 4,
              children: [
                TextButton(onPressed: () => _resolve(context, row, 'rejected', false, reload), child: const Text('Rad etish')),
                TextButton(onPressed: () => _resolve(context, row, 'resolved', true, reload), child: const Text('Yashirish')),
              ],
            ),
    ));
  }
}

class _Deletions extends StatelessWidget {
  const _Deletions();

  Future<void> _complete(BuildContext context, Json row, VoidCallback reload) async {
    if (!await confirmAction(context, 'Mehmon maʼlumoti butunlay oʻchirilsinmi?', action: 'Oʻchirish') || !context.mounted) return;
    await attempt(context, () async {
      await db.rpc<dynamic>('admin_complete_deletion', params: {'p_id': row['id']});
    });
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return _adminList('deletions', (context, row, reload) => ListTile(
      title: Text('${row['phone']}'),
      subtitle: Text(formatDate(row['created_at'])),
      trailing: row['status'] == 'open' ? TextButton(onPressed: () => _complete(context, row, reload), child: const Text('Bajarish')) : const Text('Bajarilgan'),
    ));
  }
}
