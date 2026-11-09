import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

class DashboardSection extends StatelessWidget {
  const DashboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    return LoadView<Json>(
      load: () => rpcJson('admin_dashboard'),
      builder: (context, stats, _) => SectionList(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatTile('Faol bizneslar', stats['active']),
              StatTile('Yangi, 30 kun', stats['new_30d']),
              StatTile('Sinovdagilar', stats['trial']),
              StatTile('Ketganlar', stats['churned']),
              StatTile('MRR', formatMoney(stats['mrr_uzs'] as num)),
              StatTile('Bu oy toʻlovlar', formatMoney(stats['paid_this_month'] as num)),
              StatTile('Muddati oʻtganlar', stats['overdue']),
            ],
          ),
          const SectionTitle('Oxirgi 14 kun'),
          RowsTable(
            columns: const ['Kun', 'Skan', 'Aʼzo', 'Shtamp', 'Fikr'],
            rows: [
              for (final day in (stats['daily'] as List).cast<Json>().reversed)
                [for (final field in ['day', 'scans', 'members', 'stamps', 'feedback']) Text('${day[field]}')],
            ],
          ),
        ],
      ),
    );
  }
}
