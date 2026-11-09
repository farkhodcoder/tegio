import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

import '../state.dart';

const _statuses = {'new': 'Yangi', 'in_progress': 'Jarayonda', 'resolved': 'Hal qilindi', 'archived': 'Arxiv'};

class FeedbackSection extends StatefulWidget {
  const FeedbackSection({super.key});

  @override
  State<FeedbackSection> createState() => _FeedbackSectionState();
}

class _FeedbackSectionState extends State<FeedbackSection> {
  String? _status;
  int? _rating;
  String? _location;

  Future<List<Json>> _load() {
    var query = db.from('feedback').select().eq('business_id', biz.id);
    if (_status != null) query = query.eq('status', _status!);
    if (_rating != null) query = query.eq('rating', _rating!);
    if (_location != null) query = query.eq('location_id', _location!);
    return query.order('created_at', ascending: false).limit(200);
  }

  Future<void> _reply(Json row, VoidCallback reload) async {
    final reply = await askText(context, 'Javob', initial: row['reply'] as String? ?? '', maxLines: 4);
    if (reply == null || !mounted) return;
    await _update(row, {'reply': reply, 'status': 'resolved'}, reload);
  }

  Future<void> _update(Json row, Json fields, VoidCallback reload) async {
    await attempt(context, () async {
      await db.from('feedback').update(fields).eq('id', row['id'] as String);
    });
    reload();
  }

  Widget _filter<T>(String label, T? value, Map<T, String> options, ValueChanged<T?> onChanged) {
    return DropdownButton<T?>(
      value: value,
      hint: Text(label),
      items: [
        DropdownMenuItem<T?>(child: Text('$label: hammasi')),
        for (final entry in options.entries) DropdownMenuItem<T?>(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Json>>(
      key: ValueKey('$_status/$_rating/$_location'),
      load: _load,
      builder: (context, rows, reload) => SectionList(
        children: [
          Wrap(
            spacing: 16,
            children: [
              _filter('Holat', _status, _statuses, (value) => setState(() => _status = value)),
              _filter('Baho', _rating, {for (var i = 5; i >= 1; i--) i: '$i'}, (value) => setState(() => _rating = value)),
              _filter('Filial', _location, {for (final l in biz.locations) l['id'] as String: l['name'] as String}, (value) => setState(() => _location = value)),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty) const Text('Hozircha fikrlar yoʻq.'),
          for (final row in rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('★' * (row['rating'] as int)),
                        const Spacer(),
                        Text(formatDate(row['created_at']), style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    if ((row['text'] as String? ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(row['text'] as String)),
                    if ((row['contact'] as String? ?? '').isNotEmpty) Text('Aloqa: ${row['contact']}'),
                    if (row['reply'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Javob: ${row['reply']}')),
                    Row(
                      children: [
                        Chip(label: Text(_statuses[row['status']] ?? '${row['status']}')),
                        const Spacer(),
                        TextButton(onPressed: () => _reply(row, reload), child: const Text('Javob')),
                        if (row['status'] == 'new') TextButton(onPressed: () => _update(row, {'status': 'in_progress'}, reload), child: const Text('Jarayonda')),
                        if (row['status'] != 'archived') TextButton(onPressed: () => _update(row, {'status': 'archived'}, reload), child: const Text('Arxiv')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
