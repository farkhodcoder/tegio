import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

import '../state.dart';
import 'page_setup.dart' show parseHex;

class LoyaltySection extends StatelessWidget {
  const LoyaltySection({super.key});

  Future<(Json, List<Json>)> _load() async {
    final program = await db.from('loyalty_programs').select().eq('business_id', biz.id).single();
    final tiers = await db.from('reward_tiers').select().eq('program_id', program['id'] as String).order('stamps_required');
    return (program, tiers);
  }

  @override
  Widget build(BuildContext context) {
    return LoadView(
      load: _load,
      builder: (context, data, reload) => _LoyaltyForm(program: data.$1, tiers: data.$2, reload: reload),
    );
  }
}

class _LoyaltyForm extends StatefulWidget {
  const _LoyaltyForm({required this.program, required this.tiers, required this.reload});

  final Json program;
  final List<Json> tiers;
  final VoidCallback reload;

  @override
  State<_LoyaltyForm> createState() => _LoyaltyFormState();
}

class _LoyaltyFormState extends State<_LoyaltyForm> {
  late bool _enabled = widget.program['enabled'] as bool;
  late final _interval = TextEditingController(text: '${widget.program['stamp_interval_min']}');
  late final _expiry = TextEditingController(text: '${widget.program['stamp_expiry_days'] ?? ''}');
  late final Json _card = Json.of(widget.program['card_json'] as Json? ?? const {});
  late final _color = TextEditingController(text: _card['color'] as String? ?? '');
  late final _text = TextEditingController(text: _card['text'] as String? ?? '');

  Future<void> _save() async {
    final interval = int.tryParse(_interval.text);
    final expiry = _expiry.text.trim().isEmpty ? null : int.tryParse(_expiry.text);
    if (interval == null || interval < 0 || (_expiry.text.trim().isNotEmpty && (expiry == null || expiry < 1))) {
      showMessage(context, 'Oraliq va muddatni raqam bilan kiriting.');
      return;
    }
    if (_enabled && widget.tiers.isEmpty) {
      showMessage(context, 'Yoqishdan oldin kamida bitta mukofot qoʻshing.');
      return;
    }
    await attempt(context, done: 'Saqlandi', () async {
      await db.from('loyalty_programs').update({
        'enabled': _enabled,
        'stamp_interval_min': interval,
        'stamp_expiry_days': expiry,
        'card_json': {..._card, 'color': _color.text.trim(), 'text': _text.text.trim()},
      }).eq('id', widget.program['id'] as String);
    });
    widget.reload();
  }

  Future<void> _addTier() async {
    final result = await showDialog<Json>(context: context, builder: (_) => const _TierDialog());
    if (result == null || !mounted) return;
    await attempt(context, () async {
      await db.from('reward_tiers').insert({...result, 'business_id': biz.id, 'program_id': widget.program['id']});
    });
    widget.reload();
  }

  Future<void> _removeTier(Json tier) async {
    // Olingan mukofotlar jurnali shu bosqichga bog'langan, shuning uchun baza rad etishi mumkin.
    await attempt(context, () async {
      await db.from('reward_tiers').delete().eq('id', tier['id'] as String);
    });
    widget.reload();
  }

  @override
  Widget build(BuildContext context) {
    final color = parseHex(_color.text) ?? Theme.of(context).colorScheme.primary;
    final top = widget.tiers.isEmpty ? 10 : widget.tiers.last['stamps_required'] as int;
    return SectionList(
      children: [
        SwitchListTile(title: const Text('Sodiqlik dasturi yoqilgan'), value: _enabled, onChanged: (value) => setState(() => _enabled = value)),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(biz.business['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              Text(_text.text, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (var i = 0; i < top && i < 24; i++) const Icon(Icons.circle_outlined, color: Colors.white, size: 20)],
              ),
            ],
          ),
        ),
        TextField(controller: _color, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Karta rangi', hintText: '#E4572E')),
        const SizedBox(height: 12),
        TextField(controller: _text, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Karta matni')),
        const SizedBox(height: 12),
        TextField(controller: _interval, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bir mehmonga shtamp oraligʻi, daqiqa')),
        const SizedBox(height: 12),
        TextField(controller: _expiry, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Shtamp muddati, kun', helperText: 'Boʻsh qoldirilsa, muddatsiz')),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _save, child: const Text('Saqlash'))),
        SectionTitle('Mukofotlar', trailing: TextButton(onPressed: _addTier, child: const Text('Qoʻshish'))),
        if (widget.tiers.isEmpty) const Text('Masalan: 5 shtamp — pishiriq, 10 shtamp — bepul qahva.'),
        for (final tier in widget.tiers)
          ListTile(
            leading: CircleAvatar(child: Text('${tier['stamps_required']}')),
            title: Text(tier['title'] as String),
            subtitle: Text(tier['expiry_days'] == null ? 'Muddatsiz' : '${tier['expiry_days']} kun amal qiladi'),
            trailing: IconButton(tooltip: 'Oʻchirish', icon: const Icon(Icons.delete_outline), onPressed: () => _removeTier(tier)),
          ),
      ],
    );
  }
}

class _TierDialog extends StatefulWidget {
  const _TierDialog();

  @override
  State<_TierDialog> createState() => _TierDialogState();
}

class _TierDialogState extends State<_TierDialog> {
  final _stamps = TextEditingController();
  final _title = TextEditingController();
  final _expiry = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mukofot'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _stamps, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nechta shtampda')),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Mukofot nomi')),
          TextField(controller: _expiry, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Muddati, kun (ixtiyoriy)')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
        FilledButton(
          onPressed: () {
            final stamps = int.tryParse(_stamps.text);
            final expiry = int.tryParse(_expiry.text);
            if (stamps == null || stamps < 1 || _title.text.trim().isEmpty) return;
            Navigator.pop(context, <String, dynamic>{
              'stamps_required': stamps,
              'title': _title.text.trim(),
              'expiry_days': expiry != null && expiry > 0 ? expiry : null,
            });
          },
          child: const Text('Qoʻshish'),
        ),
      ],
    );
  }
}
