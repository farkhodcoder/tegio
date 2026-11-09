import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

import '../state.dart';

class CustomersSection extends StatelessWidget {
  const CustomersSection({super.key});

  void _export(List<Json> rows) {
    downloadCsv('tegio-mijozlar.csv', [
      ['Ism', 'Telefon', 'Shtamplar', 'Oxirgi tashrif', 'Marketing roziligi'],
      for (final row in rows) [row['name'], row['phone'], row['stamps'], formatDate(row['last_visit']), row['marketing_consent'] == true ? 'Ha' : 'Yoʻq'],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Json>>(
      load: () => rpcList('business_customers', {'p_business_id': biz.id}),
      builder: (context, rows, _) => SectionList(
        children: [
          SectionTitle(
            'Mijozlar: ${rows.length} ta',
            // Eksportda telefonlar bazaning o'zida egasidan boshqaga yashiriladi (B-37).
            trailing: FilledButton(onPressed: rows.isEmpty ? null : () => _export(rows), child: const Text('Excel')),
          ),
          RowsTable(
            columns: const ['Ism', 'Telefon', 'Shtamp', 'Oxirgi tashrif', 'Rozilik'],
            rows: [
              for (final row in rows)
                [
                  Text('${row['name'] ?? '—'}'),
                  Text('${row['phone']}'),
                  Text('${row['stamps']}'),
                  Text(formatDate(row['last_visit'])),
                  Icon(row['marketing_consent'] == true ? Icons.check : Icons.remove, size: 18),
                ],
            ],
          ),
        ],
      ),
    );
  }
}
