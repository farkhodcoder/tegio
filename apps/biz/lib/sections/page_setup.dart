import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:tegio_core/tegio_core.dart';

import '../state.dart';

const _buttonKinds = {
  'menu': 'Menyu',
  'wifi': 'Wi-Fi',
  'loyalty': 'Sodiqlik kartasi',
  'feedback': 'Fikr qoldirish',
  'instagram': 'Instagram',
  'telegram': 'Telegram',
  '2gis': '2GIS',
  'yandex': 'Yandex Xarita',
};
const _internalKinds = {'menu', 'wifi', 'loyalty', 'feedback'};

Color? parseHex(String value) {
  final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(value.trim());
  return match == null ? null : Color(int.parse('FF${match[1]}', radix: 16));
}

/// Rasmni `media/<biznes id>/...` ga yuklab, ochiq manzilini qaytaradi (bucket siyosati shu yo'lni talab qiladi).
Future<String?> uploadImage(String name) async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
  if (file == null) return null;
  final type = file.mimeType ?? 'image/jpeg';
  final path = '${biz.id}/$name-${DateTime.now().millisecondsSinceEpoch}.${type.split('/').last}';
  await db.storage.from('media').uploadBinary(path, await file.readAsBytes(), fileOptions: FileOptions(contentType: type));
  return db.storage.from('media').getPublicUrl(path);
}

class PageSetupSection extends StatelessWidget {
  const PageSetupSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionList(children: [_BrandCard(), _ButtonsCard(), _WifiCard(), _TagsCard()]);
  }
}

class _BrandCard extends StatefulWidget {
  const _BrandCard();

  @override
  State<_BrandCard> createState() => _BrandCardState();
}

class _BrandCardState extends State<_BrandCard> {
  final Json _brand = Json.of(biz.business['brand'] as Json? ?? const {});
  late final _tagline = TextEditingController(text: _brand['tagline'] as String? ?? '');
  late final _primary = TextEditingController(text: _brand['primary'] as String? ?? '');
  late final _telegram = TextEditingController(text: biz.business['telegram_chat_id'] as String? ?? '');

  Future<void> _upload(String field) async {
    await attempt(context, () async {
      final url = await uploadImage(field);
      if (url != null) setState(() => _brand[field == 'logo' ? 'logo_url' : 'cover_url'] = url);
    });
  }

  Future<void> _save() async {
    if (_primary.text.trim().isNotEmpty && parseHex(_primary.text) == null) {
      showMessage(context, 'Rang #A1B2C3 koʻrinishida boʻlsin.');
      return;
    }
    await attempt(context, done: 'Saqlandi', () async {
      await db.from('businesses').update({
        'brand_json': {..._brand, 'tagline': _tagline.text.trim(), 'primary': _primary.text.trim()},
        'telegram_chat_id': _telegram.text.trim().isEmpty ? null : _telegram.text.trim(),
      }).eq('id', biz.id);
      await biz.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = parseHex(_primary.text) ?? Theme.of(context).colorScheme.primary;
    final logo = _brand['logo_url'] as String?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Koʻrinish', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  if (logo != null) ...[
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(logo, width: 48, height: 48, fit: BoxFit.cover)),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(biz.business['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        Text(_tagline.text, style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: () => _upload('logo'), child: const Text('Logotip')),
                OutlinedButton(onPressed: () => _upload('cover'), child: const Text('Muqova')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _tagline, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Shior')),
            const SizedBox(height: 12),
            TextField(controller: _primary, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Asosiy rang', hintText: '#E4572E')),
            if (biz.isOwner) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _telegram,
                decoration: const InputDecoration(labelText: 'Telegram chat ID', helperText: 'Yangi fikrlar shu chatga keladi'),
              ),
            ],
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _save, child: const Text('Saqlash'))),
          ],
        ),
      ),
    );
  }
}

class _ButtonsCard extends StatelessWidget {
  const _ButtonsCard();

  Future<List<Json>> _load() =>
      db.from('landing_items').select().eq('location_id', biz.locationId).order('position');

  Future<void> _add(BuildContext context, List<Json> items, VoidCallback reload) async {
    final used = items.map((item) => item['kind']).toSet();
    final kind = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Tugma qoʻshish'),
        children: [
          for (final entry in _buttonKinds.entries.where((entry) => !used.contains(entry.key)))
            SimpleDialogOption(onPressed: () => Navigator.pop(context, entry.key), child: Text(entry.value)),
        ],
      ),
    );
    if (kind == null || !context.mounted) return;
    String? url;
    if (!_internalKinds.contains(kind)) {
      url = await askText(context, '${_buttonKinds[kind]} havolasi', hint: 'https://');
      if (url == null || url.isEmpty) return;
    }
    if (!context.mounted) return;
    await attempt(context, () async {
      await db.from('landing_items').insert({
        'business_id': biz.id,
        'location_id': biz.locationId,
        'kind': kind,
        'url': url,
        'position': items.length,
      });
    });
    reload();
  }

  Future<void> _reorder(List<Json> items, int from, int to) async {
    final moved = items.removeAt(from);
    items.insert(to, moved);
    for (var index = 0; index < items.length; index++) {
      await db.from('landing_items').update({'position': index}).eq('id', items[index]['id'] as String);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Json>>(
      load: _load,
      builder: (context, items, reload) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Sahifa tugmalari',
            trailing: TextButton(onPressed: () => _add(context, items, reload), child: const Text('Qoʻshish')),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) => attempt(context, () => _reorder(items, from, to)).then((_) => reload()),
            children: [
              for (final (index, item) in items.indexed)
                ListTile(
                  key: ValueKey(item['id']),
                  leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_indicator)),
                  title: Text(_buttonKinds[item['kind']] ?? '${item['kind']}'),
                  subtitle: item['url'] == null ? null : Text(item['url'] as String, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: item['enabled'] as bool,
                        onChanged: (value) => attempt(context, () async {
                          await db.from('landing_items').update({'enabled': value}).eq('id', item['id'] as String);
                        }).then((_) => reload()),
                      ),
                      IconButton(
                        tooltip: 'Oʻchirish',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => attempt(context, () async {
                          await db.from('landing_items').delete().eq('id', item['id'] as String);
                        }).then((_) => reload()),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WifiCard extends StatefulWidget {
  const _WifiCard();

  @override
  State<_WifiCard> createState() => _WifiCardState();
}

class _WifiCardState extends State<_WifiCard> {
  final _ssid = TextEditingController(text: biz.location['wifi_ssid'] as String? ?? '');
  final _password = TextEditingController();
  final _google = TextEditingController(text: biz.location['google_review_url'] as String? ?? '');

  Future<void> _save() async {
    await attempt(context, done: 'Saqlandi', () async {
      await callApi('/biz/wifi', {'location_id': biz.locationId, 'ssid': _ssid.text, 'password': _password.text});
      await db.from('locations').update({'google_review_url': _google.text.trim().isEmpty ? null : _google.text.trim()}).eq('id', biz.locationId);
      await biz.load();
    });
    _password.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Wi-Fi va Google sharh'),
        TextField(controller: _ssid, decoration: const InputDecoration(labelText: 'Wi-Fi nomi')),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Wi-Fi paroli', helperText: 'Bazada shifrlangan holda saqlanadi. Saqlashda qayta kiriting.'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _google, decoration: const InputDecoration(labelText: 'Google sharh havolasi')),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _save, child: const Text('Saqlash'))),
      ],
    );
  }
}

class _TagsCard extends StatelessWidget {
  const _TagsCard();

  Future<List<Json>> _load() => db.from('tags').select('code,table_label,type').eq('location_id', biz.locationId).order('created_at');

  Future<void> _create(BuildContext context, VoidCallback reload, int existing) async {
    final answer = await askText(context, 'Nechta stol qoʻshilsin?', initial: '10', keyboard: TextInputType.number);
    final count = int.tryParse(answer ?? '');
    if (count == null || count < 1 || count > 100 || !context.mounted) return;
    await attempt(context, () async {
      await db.rpc<dynamic>('create_table_tags', params: {
        'p_business_id': biz.id,
        'p_location_id': biz.locationId,
        'p_labels': [for (var i = 1; i <= count; i++) '${existing + i}'],
        'p_type': 'qr',
      });
    });
    reload();
  }

  String _link(Json tag) => '${TegioConfig.publicUrl}/${biz.business['slug']}?t=${tag['code']}';

  Future<void> _print(List<Json> tags) async {
    final font = await PdfGoogleFonts.notoSansRegular();
    final document = pw.Document(theme: pw.ThemeData.withFont(base: font));
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              for (final tag in tags)
                pw.Container(
                  width: 160,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                  child: pw.Column(
                    children: [
                      pw.Text(biz.business['name'] as String),
                      pw.SizedBox(height: 6),
                      pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: _link(tag), width: 130, height: 130),
                      pw.SizedBox(height: 6),
                      pw.Text('Stol ${tag['table_label'] ?? ''}'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(name: 'tegio-yorliqlar.pdf', onLayout: (_) => document.save());
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Json>>(
      load: _load,
      builder: (context, tags, reload) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Stol yorliqlari: ${tags.length} ta',
            trailing: Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: () => _create(context, reload, tags.length), child: const Text('Qoʻshish')),
                if (tags.isNotEmpty)
                  FilledButton(onPressed: () => attempt(context, () => _print(tags)), child: const Text('PDF chop etish')),
              ],
            ),
          ),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final tag in tags) Chip(label: Text('Stol ${tag['table_label'] ?? ''}'))]),
        ],
      ),
    );
  }
}
