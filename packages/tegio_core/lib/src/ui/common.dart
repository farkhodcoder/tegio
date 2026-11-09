import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/api.dart';

const _apiErrors = {
  'forbidden': 'Bu amal uchun ruxsatingiz yoʻq.',
  'unauthorized': 'Qaytadan kiring.',
  'rate_limited': 'Juda koʻp urinish. Birozdan keyin qayta urinib koʻring.',
  'sms_unavailable': 'SMS hozir yuborilmadi. Birozdan keyin qayta urinib koʻring.',
  'bad_phone': 'Telefon raqami notoʻgʻri.',
  'bad_code': 'Kod notoʻgʻri yoki eskirgan.',
  'provider_unavailable': 'Bu toʻlov usuli hali ulanmagan.',
  'ai_unavailable': 'AI xizmati hali ulanmagan.',
  'ai_failed': 'AI natija bermadi. Rasmni tiniqroq olib qayta urinib koʻring.',
  'card_not_found': 'Bu raqam bilan karta topilmadi.',
  'wrong_business': 'Bu karta shu biznesga tegishli emas.',
  'invite_failed': 'Taklif yuborilmadi.',
};

String errorText(Object error) {
  if (error is TegioApiException) return _apiErrors[error.code] ?? 'Xatolik yuz berdi.';
  if (error is PostgrestException) {
    if (error.code == '42501') return error.message == 'mfa_required' ? 'Avval 2FA kodini tasdiqlang.' : _apiErrors['forbidden']!;
    if (error.code == '23505') return 'Bu qiymat allaqachon band.';
    if (error.code == '23514') return 'Kiritilgan qiymat qabul qilinmadi.';
  }
  if (error is AuthException) return 'Kirish amalga oshmadi. Maʼlumotlarni tekshiring.';
  return 'Xatolik yuz berdi. Internetni tekshirib qayta urinib koʻring.';
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Amalni bajaradi, xato bo'lsa xabar ko'rsatadi. Muvaffaqiyatda `true`.
Future<bool> attempt(BuildContext context, Future<void> Function() action, {String? done}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    return true;
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(error))));
    return false;
  }
}

/// Yuklash, xato va qayta urinishni bir joyda boshqaradi.
class LoadView<T> extends StatefulWidget {
  const LoadView({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload) builder;

  @override
  State<LoadView<T>> createState() => _LoadViewState<T>();
}

class _LoadViewState<T> extends State<LoadView<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(errorText(snapshot.error!), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _reload, child: const Text('Qayta urinish')),
              ],
            ),
          );
        }
        // hasData emas: natijasi null yoki void bo'lgan yuklashlar ham tugaydi.
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        return widget.builder(context, snapshot.data as T, _reload);
      },
    );
  }
}

/// Bo'lim sahifasi: o'qishga qulay kenglik, telefon va kompyuterda bir xil.
class SectionList extends StatelessWidget {
  const SectionList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(padding: const EdgeInsets.all(16), children: children),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          ?trailing,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile(this.label, this.value, {super.key});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${value ?? '—'}', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ustunlari aniq, gorizontal siljiydigan jadval.
class RowsTable extends StatelessWidget {
  const RowsTable({super.key, required this.columns, required this.rows, this.empty = 'Hozircha maʼlumot yoʻq.'});

  final List<String> columns;
  final List<List<Widget>> rows;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(empty));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [for (final column in columns) DataColumn(label: Text(column))],
        rows: [
          for (final row in rows) DataRow(cells: [for (final cell in row) DataCell(cell)]),
        ],
      ),
    );
  }
}

Future<String?> askText(
  BuildContext context,
  String title, {
  String initial = '',
  String? hint,
  TextInputType? keyboard,
  int maxLines = 1,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Saqlash')),
      ],
    ),
  );
}

Future<bool> confirmAction(BuildContext context, String title, {String action = 'Tasdiqlash'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Bekor qilish')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}

String formatDate(Object? iso) {
  final date = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (date == null) return '—';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} ${two(date.hour)}:${two(date.minute)}';
}

String formatMoney(num? value) {
  if (value == null) return '—';
  final digits = value.round().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  return '$grouped soʻm';
}
