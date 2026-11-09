import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

import '../state.dart';

class DashboardSection extends StatefulWidget {
  const DashboardSection({super.key});

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  int _days = 30;

  Future<(Json, List<(String, bool)>)> _load() async {
    final stats = await rpcJson('business_stats', {'p_business_id': biz.id, 'p_days': _days});
    final menus = await db.from('menus').select('id').eq('business_id', biz.id);
    final program = await db.from('loyalty_programs').select('enabled').eq('business_id', biz.id).maybeSingle();
    final tags = await db.from('tags').select('id').eq('business_id', biz.id).limit(1);
    final brand = biz.business['brand'] as Json? ?? const {};
    return (
      stats,
      [
        ('Sahifa: logotip yoki rang', brand.isNotEmpty),
        ('Menyu', menus.isNotEmpty),
        ('Wi-Fi', biz.location['wifi_ssid'] != null),
        ('Sodiqlik kartasi', program?['enabled'] == true),
        ('Stol yorligʻi', tags.isNotEmpty),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadView(
      key: ValueKey(_days),
      load: _load,
      builder: (context, data, _) {
        final (stats, checklist) = data;
        final open = checklist.where((step) => !step.$2);
        List<List<Widget>> rows(String key, List<String> fields) => [
          for (final row in (stats[key] as List).cast<Json>())
            [for (final field in fields) Text('${row[field] ?? '—'}')],
        ];
        return SectionList(
          children: [
            if (open.isNotEmpty) ...[
              const SectionTitle('Sozlashni yakunlang'),
              Card(
                child: Column(
                  children: [
                    for (final (label, done) in checklist)
                      ListTile(
                        dense: true,
                        leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked),
                        title: Text(label),
                      ),
                  ],
                ),
              ),
            ],
            SectionTitle(
              'Natijalar',
              trailing: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 kun')),
                  ButtonSegment(value: 30, label: Text('30 kun')),
                  ButtonSegment(value: 90, label: Text('90 kun')),
                ],
                selected: {_days},
                onSelectionChanged: (value) => setState(() => _days = value.first),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatTile('Skanlar', stats['scans']),
                StatTile('Yangi aʼzolar', stats['new_members']),
                StatTile('Jami aʼzolar', stats['members']),
                StatTile('Qaytganlar', stats['returning']),
                StatTile('Berilgan mukofotlar', stats['rewards_redeemed']),
                StatTile('Oʻrtacha baho', stats['avg_rating']),
              ],
            ),
            const SectionTitle('Filiallar'),
            RowsTable(columns: const ['Filial', 'Skan', 'Shtamp'], rows: rows('by_location', ['name', 'scans', 'stamps'])),
            const SectionTitle('Stollar'),
            RowsTable(columns: const ['Stol', 'Skan'], rows: rows('by_table', ['name', 'scans'])),
            const SectionTitle('Xodimlar'),
            RowsTable(columns: const ['Xodim', 'Rol', 'Shtamp'], rows: rows('by_staff', ['phone', 'role', 'stamps'])),
          ],
        );
      },
    );
  }
}
