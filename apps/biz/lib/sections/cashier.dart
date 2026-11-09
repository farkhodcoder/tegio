import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tegio_core/tegio_core.dart';

import '../setup.dart' show normalizePhone;
import '../state.dart';

String _stampErrorText(StampRejected rejected) => switch (rejected.error) {
  StampError.qrInvalid => 'QR kod notoʻgʻri.',
  StampError.qrExpired => 'QR eskirgan. Mehmon sahifani yangilasin.',
  StampError.qrUsed => 'Bu QR allaqachon ishlatilgan.',
  StampError.intervalLimit =>
    'Limit: keyingi shtamp ${rejected.retryAt == null ? 'keyinroq' : formatDate(rejected.retryAt!.toIso8601String())} da.',
  StampError.wrongBusiness => 'Bu karta shu biznesga tegishli emas.',
  StampError.cardNotFound => 'Karta topilmadi.',
  StampError.programDisabled => 'Sodiqlik dasturi oʻchirilgan.',
  StampError.unknown => 'Shtamp qoʻyilmadi.',
};

String _randomKey() {
  final random = Random.secure();
  return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

class CashierSection extends StatefulWidget {
  const CashierSection({super.key});

  @override
  State<CashierSection> createState() => _CashierSectionState();
}

class _CashierSectionState extends State<CashierSection> {
  final _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  final _phone = TextEditingController();
  StampOutcome? _result;
  Json? _member;
  String? _manualKey;
  String? _lastToken;
  bool _busy = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _stamp(Json payload) async {
    setState(() => _busy = true);
    await attempt(context, () async {
      final result = await callApi('/staff/stamp', {...payload, 'location_id': biz.locationId});
      setState(() => _result = StampOutcome.fromJson(result));
    });
    if (mounted) setState(() => _busy = false);
  }

  void _onDetect(BarcodeCapture capture) {
    final token = capture.barcodes.firstOrNull?.rawValue;
    if (token == null || token == _lastToken || _busy) return;
    _lastToken = token;
    // Kalit tokenning imzosidan olinadi: bir QR ikki marta o'qilsa ham bitta shtamp (B-29).
    final signature = token.split('.').last;
    _stamp({'token': token, 'idempotency_key': 'qr:${signature.substring(0, min(signature.length, 70))}'});
  }

  Future<void> _find() async {
    final phone = normalizePhone(_phone.text);
    if (phone.isEmpty) {
      showMessage(context, errorText(const TegioApiException('bad_phone')));
      return;
    }
    await attempt(context, () async {
      final result = await callApi('/staff/find', {'business_id': biz.id, 'phone': phone});
      if (result['ok'] != true) throw TegioApiException(result['error'] as String? ?? 'server_error');
      setState(() {
        _member = result;
        _manualKey = _randomKey();
        _result = null;
      });
    });
  }

  Future<void> _redeem(EarnedReward reward) async {
    if (!await confirmAction(context, '«${reward.title}» berilsinmi?', action: 'Berish') || !mounted) return;
    await attempt(context, done: 'Mukofot berildi', () async {
      final result = await callApi('/staff/redeem', {'reward_id': reward.id, 'location_id': biz.locationId});
      if (result['ok'] != true) throw const TegioApiException('reward_failed');
      final applied = _result;
      if (applied is StampApplied) {
        setState(() {
          _result = StampApplied(
            stamps: applied.stamps,
            duplicate: applied.duplicate,
            newRewards: applied.newRewards.where((r) => r.id != reward.id).toList(),
            availableRewards: applied.availableRewards.where((r) => r.id != reward.id).toList(),
          );
        });
      }
    });
  }

  Widget _resultCard() {
    final result = _result;
    if (result == null) return const SizedBox.shrink();
    if (result is StampRejected) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(leading: const Icon(Icons.error_outline), title: Text(_stampErrorText(result))),
      );
    }
    final applied = result as StampApplied;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.check_circle),
            title: Text(applied.duplicate ? 'Bu shtamp allaqachon qoʻyilgan' : 'Shtamp qoʻyildi'),
            subtitle: Text('Kartada: ${applied.stamps} ta'),
          ),
          for (final reward in applied.newRewards) ListTile(leading: const Icon(Icons.card_giftcard), title: Text('Yangi mukofot: ${reward.title}')),
          for (final reward in applied.availableRewards)
            ListTile(title: Text(reward.title), trailing: FilledButton(onPressed: () => _redeem(reward), child: const Text('Berish'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final member = _member;
    return SectionList(
      children: [
        Text('Filial: ${biz.location['name']}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 300,
            child: MobileScanner(
              controller: _scanner,
              onDetect: _onDetect,
              errorBuilder: (context, _) => const Center(
                child: Padding(padding: EdgeInsets.all(24), child: Text('Kamera ishlamadi. Mehmonni telefon raqami orqali toping.', textAlign: TextAlign.center)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _lastToken = null;
            _result = null;
          }),
          child: const Text('Keyingi mehmon'),
        ),
        _resultCard(),
        const SectionTitle('Telefon raqami orqali'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon raqami', prefixText: '+998 '),
                onSubmitted: (_) => _find(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _find, child: const Text('Topish')),
          ],
        ),
        if (member != null)
          Card(
            child: ListTile(
              title: Text('${member['name'] ?? 'Mehmon'} (${member['phone']})'),
              subtitle: Text('Kartada: ${member['stamps']} ta'),
              trailing: FilledButton(
                onPressed: _busy ? null : () => _stamp({'membership_id': member['membership_id'], 'idempotency_key': _manualKey}),
                child: const Text('Shtamp'),
              ),
            ),
          ),
        if (biz.canManage) const _Journal(),
      ],
    );
  }
}

/// O'zgartirilmaydigan jurnal (B-28): kim, qachon, qaysi filialda.
class _Journal extends StatelessWidget {
  const _Journal();

  static const _reasons = {'stamp': 'Shtamp', 'redeem': 'Mukofot', 'cycle_reset': 'Yangi aylana', 'expiry': 'Muddat tugadi'};

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Json>>(
      load: () => db.from('stamp_events').select('created_at,reason,delta,staff_id').eq('business_id', biz.id).order('created_at', ascending: false).limit(30),
      builder: (context, rows, reload) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle('Jurnal', trailing: IconButton(tooltip: 'Yangilash', onPressed: reload, icon: const Icon(Icons.refresh))),
          RowsTable(
            columns: const ['Vaqt', 'Amal', 'Oʻzgarish'],
            rows: [
              for (final row in rows)
                [Text(formatDate(row['created_at'])), Text(_reasons[row['reason']] ?? '${row['reason']}'), Text('${row['delta']}')],
            ],
          ),
        ],
      ),
    );
  }
}
