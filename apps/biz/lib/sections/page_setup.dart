import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:tegio_core/tegio_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state.dart';

const _buttonKinds = {
  'menu': 'Menyu',
  'wifi': 'Wi-Fi',
  'loyalty': 'Sodiqlik kartasi',
  'feedback': 'Taklif qutisi',
  'game': 'Aql oʻyini',
  'instagram': 'Instagram',
  'telegram': 'Telegram',
  '2gis': '2GIS',
  'yandex': 'Yandex Xarita',
};
const _internalKinds = {'menu', 'wifi', 'loyalty', 'feedback', 'game'};

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
    return const SectionList(children: [_BrandCard(), _LocationCard(), _ButtonsCard(), _WifiCard(), _TagsCard()]);
  }
}

class _BrandCard extends StatefulWidget {
  const _BrandCard();

  @override
  State<_BrandCard> createState() => _BrandCardState();
}

/// Tayyor ranglar: egasi bir bosishda tanlaydi, xohlasa o'z HEX'ini yozadi.
const _swatches = ['#D63A0C', '#C2255C', '#7048E8', '#1971C2', '#0C8599', '#2B8A3E', '#E67700', '#5C3D2E'];

class _BrandCardState extends State<_BrandCard> {
  final Json _brand = Json.of(biz.business['brand'] as Json? ?? const {});
  late final _name = TextEditingController(text: biz.business['name'] as String? ?? '');
  late final _tagline = TextEditingController(text: _brand['tagline'] as String? ?? '');
  late final _primary = TextEditingController(text: _brand['primary'] as String? ?? '');
  late final _telegram = TextEditingController(text: biz.business['telegram_chat_id'] as String? ?? '');
  String? _uploading;

  String get _pageUrl => '${TegioConfig.publicUrl}/${biz.business['slug']}';

  Future<void> _upload(String field) async {
    setState(() => _uploading = field);
    await attempt(context, () async {
      final url = await uploadImage(field);
      if (url != null) setState(() => _brand['${field}_url'] = url);
    });
    if (mounted) setState(() => _uploading = null);
  }

  Future<void> _save() async {
    if (_primary.text.trim().isNotEmpty && parseHex(_primary.text) == null) {
      showMessage(context, 'Rang #A1B2C3 koʻrinishida boʻlsin.');
      return;
    }
    if (_name.text.trim().length < 2) {
      showMessage(context, 'Biznes nomini yozing.');
      return;
    }
    await attempt(context, done: 'Saqlandi. Sahifangiz yangilandi.', () async {
      final brand = {..._brand, 'tagline': _tagline.text.trim(), 'primary': _primary.text.trim()}
        ..removeWhere((_, value) => value == null || value == '');
      await db.from('businesses').update({
        if (biz.isOwner) 'name': _name.text.trim(),
        'brand_json': brand,
        if (biz.isOwner) 'telegram_chat_id': _telegram.text.trim().isEmpty ? null : _telegram.text.trim(),
      }).eq('id', biz.id);
      await biz.load();
    });
  }

  Widget _imageButtons(String field, String label) {
    final has = _brand['${field}_url'] != null;
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _uploading != null ? null : () => _upload(field),
          icon: _uploading == field
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(has ? '$label: almashtirish' : '$label yuklash'),
        ),
        if (has)
          IconButton(
            tooltip: '$label: oʻchirish',
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _brand.remove('${field}_url')),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = parseHex(_primary.text) ?? Theme.of(context).colorScheme.primary;
    final logo = _brand['logo_url'] as String?;
    final cover = _brand['cover_url'] as String?;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Profil va koʻrinish', style: text.titleMedium),
            const SizedBox(height: 4),
            Text('Mehmon yorliqni skan qilganda aynan shunday koʻradi.', style: text.bodySmall),
            const SizedBox(height: 12),
            // Mehmon sahifasining tepa qismi: banner, logotip va nom.
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: color,
                        image: cover == null ? null : DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -34),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFFD8A8),
                                border: Border.all(color: Colors.white, width: 4),
                                image: logo == null ? null : DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover),
                              ),
                              child: logo != null
                                  ? null
                                  : Text(
                                      _name.text.isEmpty ? '?' : _name.text.characters.first.toUpperCase(),
                                      style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_name.text, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                                    if (_tagline.text.isNotEmpty) Text(_tagline.text, style: text.bodySmall),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Wrap(spacing: 8, runSpacing: 4, children: [_imageButtons('logo', 'Logotip'), _imageButtons('cover', 'Banner')]),
            const SizedBox(height: 4),
            Text('Banner uchun keng rasm (taxminan 1600×800), logotip uchun kvadrat rasm. 5 MB gacha: JPG, PNG yoki WebP.', style: text.bodySmall),
            const SizedBox(height: 16),
            if (biz.isOwner) ...[
              TextField(controller: _name, onChanged: (_) => setState(() {}), maxLength: 80, decoration: const InputDecoration(labelText: 'Biznes nomi')),
              const SizedBox(height: 4),
            ],
            TextField(
              controller: _tagline,
              onChanged: (_) => setState(() {}),
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Shior', hintText: 'Toshkentning issiq noni va achchiq choyi'),
            ),
            const SizedBox(height: 4),
            Text('Asosiy rang', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hex in _swatches)
                  InkResponse(
                    onTap: () => setState(() => _primary.text = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: parseHex(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _primary.text.toUpperCase() == hex ? Theme.of(context).colorScheme.onSurface : Colors.white,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _primary,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Yoki oʻz rangingiz', hintText: '#E4572E'),
            ),
            if (biz.isOwner) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _telegram,
                decoration: const InputDecoration(labelText: 'Telegram chat ID', helperText: 'Yangi fikrlar shu chatga keladi'),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse(_pageUrl), webOnlyWindowName: '_blank'),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Sahifani ochish'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _pageUrl));
                        if (context.mounted) showMessage(context, 'Havola nusxalandi: $_pageUrl');
                      },
                      icon: const Icon(Icons.link),
                      label: const Text('Havolani nusxalash'),
                    ),
                  ],
                ),
                FilledButton(onPressed: _save, child: const Text('Saqlash')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Filial nomi va manzili sahifada nom ostida ko'rinadi.
class _LocationCard extends StatefulWidget {
  const _LocationCard();

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  final _name = TextEditingController(text: biz.location['name'] as String? ?? '');
  final _address = TextEditingController(text: biz.location['address'] as String? ?? '');

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showMessage(context, 'Filial nomini yozing.');
      return;
    }
    await attempt(context, done: 'Saqlandi', () async {
      await db.from('locations').update({
        'name': _name.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      }).eq('id', biz.locationId);
      await biz.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Filial'),
        TextField(controller: _name, maxLength: 80, decoration: const InputDecoration(labelText: 'Filial nomi', hintText: 'Chilonzor')),
        const SizedBox(height: 4),
        TextField(controller: _address, maxLength: 200, decoration: const InputDecoration(labelText: 'Manzil', hintText: 'Toshkent, Chilonzor 9-kvartal')),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          children: [
            if (biz.isOwner) TextButton.icon(onPressed: _addLocation, icon: const Icon(Icons.add_business_outlined), label: const Text('Yangi filial')),
            FilledButton(onPressed: _save, child: const Text('Saqlash')),
          ],
        ),
      ],
    );
  }

  // Yangi filial odatiy tugmalar bilan ochiladi, aks holda uning sahifasi bo'sh bo'lardi.
  Future<void> _addLocation() async {
    final name = await askText(context, 'Yangi filial nomi', hint: 'Yunusobod');
    if (name == null || name.isEmpty || !mounted) return;
    await attempt(context, done: 'Filial qoʻshildi', () async {
      final location = await db.from('locations').insert({'business_id': biz.id, 'name': name}).select('id').single();
      await db.from('landing_items').insert([
        for (final (index, kind) in ['loyalty', 'menu', 'wifi', 'feedback', 'game'].indexed)
          {'business_id': biz.id, 'location_id': location['id'], 'kind': kind, 'position': index},
      ]);
      await biz.load();
      biz.selectLocation(location['id'] as String);
    });
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

  // Tugma matnini (va tashqi havolani) o'zgartirish. Bo'sh matn odatiy nomga qaytaradi.
  Future<void> _edit(BuildContext context, Json item, VoidCallback reload) async {
    final kind = item['kind'] as String;
    final label = await askText(context, 'Tugma matni', initial: item['label'] as String? ?? '', hint: _buttonKinds[kind] ?? kind);
    if (label == null || !context.mounted) return;
    String? url = item['url'] as String?;
    if (!_internalKinds.contains(kind)) {
      url = await askText(context, '${_buttonKinds[kind] ?? kind} havolasi', initial: url ?? '', hint: 'https://');
      if (url == null || url.isEmpty || !context.mounted) return;
    }
    await attempt(context, () async {
      await db.from('landing_items').update({'label': label.isEmpty ? null : label, 'url': url}).eq('id', item['id'] as String);
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
                  onTap: () => _edit(context, item, reload),
                  title: Text((item['label'] as String?) ?? _buttonKinds[item['kind']] ?? '${item['kind']}'),
                  subtitle: Text(
                    [
                      if (item['label'] != null) _buttonKinds[item['kind']] ?? '${item['kind']}',
                      if (item['url'] != null) item['url'] as String,
                    ].join(' · ').ifEmpty('Matnini oʻzgartirish uchun bosing'),
                    overflow: TextOverflow.ellipsis,
                  ),
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

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
