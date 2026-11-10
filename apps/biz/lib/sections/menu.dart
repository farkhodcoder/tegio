import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tegio_core/tegio_core.dart';

import '../state.dart';
import 'page_setup.dart' show uploadImage;

const _locales = {'uz-Cyrl': 'Ўзбекча', 'ru': 'Русский', 'en': 'English'};
const _dayNames = ['Yak', 'Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha'];

Future<void> saveTranslation(String type, String id, String field, String locale, String value) async {
  final row = {'entity_type': type, 'entity_id': id, 'field': field, 'locale': locale};
  if (value.trim().isEmpty) {
    await db.from('translations').delete().match(row);
  } else {
    await db.from('translations').upsert({...row, 'business_id': biz.id, 'value': value.trim()});
  }
}

class _MenuData {
  _MenuData(this.menus, this.categories, this.items, List<Json> translations) {
    for (final row in translations) {
      _text['${row['entity_id']}/${row['field']}/${row['locale']}'] = row['value'] as String;
    }
  }

  final List<Json> menus;
  final List<Json> categories;
  final List<Json> items;
  final Map<String, String> _text = {};

  String text(Object? id, String field, [String locale = 'uz']) => _text['$id/$field/$locale'] ?? '';
  List<Json> categoriesOf(Object? menu) => categories.where((c) => c['menu_id'] == menu).toList();
  List<Json> itemsOf(Object? category) => items.where((i) => i['category_id'] == category).toList();
}

class MenuSection extends StatefulWidget {
  const MenuSection({super.key});

  @override
  State<MenuSection> createState() => _MenuSectionState();
}

class _MenuSectionState extends State<MenuSection> {
  String? _menuId;

  Future<_MenuData> _load() async {
    final id = biz.id;
    final rows = await Future.wait([
      db.from('menus').select().eq('business_id', id).order('position'),
      db.from('menu_categories').select().eq('business_id', id).order('position'),
      db.from('menu_items').select().eq('business_id', id).order('position'),
      db.from('translations').select().eq('business_id', id),
    ]);
    return _MenuData(rows[0], rows[1], rows[2], rows[3]);
  }

  Future<void> _addMenu(VoidCallback reload, int position) async {
    final name = await askText(context, 'Menyu nomi', hint: 'Asosiy menyu');
    if (name == null || name.isEmpty || !mounted) return;
    await attempt(context, () async {
      final row = await db.from('menus').insert({'business_id': biz.id, 'name': name, 'position': position}).select().single();
      _menuId = row['id'] as String;
    });
    reload();
  }

  Future<void> _addCategory(String menuId, int position, VoidCallback reload) async {
    final name = await askText(context, 'Kategoriya nomi', hint: 'Issiq taomlar');
    if (name == null || name.isEmpty || !mounted) return;
    await attempt(context, () async {
      final row = await db.from('menu_categories').insert({'business_id': biz.id, 'menu_id': menuId, 'position': position}).select().single();
      await saveTranslation('menu_category', row['id'] as String, 'name', 'uz', name);
    });
    reload();
  }

  Future<void> _move(String table, List<Json> rows, int index, int delta, VoidCallback reload) async {
    final other = index + delta;
    if (other < 0 || other >= rows.length) return;
    await attempt(context, () async {
      await db.from(table).update({'position': other}).eq('id', rows[index]['id'] as String);
      await db.from(table).update({'position': index}).eq('id', rows[other]['id'] as String);
    });
    reload();
  }

  Future<void> _delete(String table, String entity, String id, String title, VoidCallback reload) async {
    if (!await confirmAction(context, title, action: 'Oʻchirish') || !mounted) return;
    await attempt(context, () async {
      await db.from(table).delete().eq('id', id);
      await db.from('translations').delete().match({'entity_type': entity, 'entity_id': id});
    });
    reload();
  }

  Future<void> _schedule(Json menu, VoidCallback reload) async {
    final result = await showDialog<Object>(context: context, builder: (_) => _ScheduleDialog(menu['schedule_json'] as Json?));
    if (result == null || !mounted) return;
    await attempt(context, () async {
      await db.from('menus').update({'schedule_json': result == 'clear' ? null : result}).eq('id', menu['id'] as String);
    });
    reload();
  }

  Future<void> _importPhoto(VoidCallback reload) async {
    final navigatorContext = context;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
    if (file == null || !navigatorContext.mounted) return;
    Json? draft;
    final ok = await attempt(navigatorContext, () async {
      final result = await callApi('/ai/menu-import', {
        'business_id': biz.id,
        'media_type': file.mimeType ?? 'image/jpeg',
        'image_base64': base64Encode(await file.readAsBytes()),
      });
      draft = result['draft'] as Json;
    });
    if (!ok || draft == null || !navigatorContext.mounted) return;
    // AI natijasi faqat egasi tasdiqlagach menyuga yoziladi, u ham qoralama bo'lib (B-15).
    final accepted = await showDialog<bool>(context: navigatorContext, builder: (_) => _DraftDialog(draft!));
    if (accepted != true || !navigatorContext.mounted) return;
    await attempt(navigatorContext, done: 'Qoralama menyu yaratildi', () async {
      final menu = await db.from('menus').insert({'business_id': biz.id, 'name': 'AI qoralama', 'status': 'draft'}).select().single();
      for (final (position, category) in (draft!['categories'] as List).cast<Json>().indexed) {
        final row = await db.from('menu_categories').insert({'business_id': biz.id, 'menu_id': menu['id'], 'position': position}).select().single();
        await saveTranslation('menu_category', row['id'] as String, 'name', 'uz', category['name'] as String);
        for (final (itemPosition, item) in (category['items'] as List).cast<Json>().indexed) {
          final inserted = await db.from('menu_items').insert({
            'business_id': biz.id,
            'category_id': row['id'],
            'price_uzs': item['price_uzs'],
            'position': itemPosition,
          }).select().single();
          await saveTranslation('menu_item', inserted['id'] as String, 'name', 'uz', item['name'] as String);
          await saveTranslation('menu_item', inserted['id'] as String, 'description', 'uz', item['description'] as String);
        }
      }
      _menuId = menu['id'] as String;
    });
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<_MenuData>(
      load: _load,
      builder: (context, data, reload) {
        final selected = data.menus.where((m) => m['id'] == _menuId);
        final menu = selected.isNotEmpty ? selected.first : (data.menus.isEmpty ? null : data.menus.first);
        final categories = menu == null ? <Json>[] : data.categoriesOf(menu['id']);
        return SectionList(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final m in data.menus)
                  ChoiceChip(
                    label: Text(m['name'] as String),
                    selected: m['id'] == menu?['id'],
                    onSelected: (_) => setState(() => _menuId = m['id'] as String),
                  ),
                OutlinedButton(onPressed: () => _addMenu(reload, data.menus.length), child: const Text('Yangi menyu')),
                OutlinedButton(onPressed: () => _importPhoto(reload), child: const Text('Rasmdan (AI)')),
              ],
            ),
            if (menu != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Saytda koʻrinadi'),
                      value: menu['status'] == 'published',
                      onChanged: (value) => attempt(context, () async {
                        await db.from('menus').update({'status': value ? 'published' : 'draft'}).eq('id', menu['id'] as String);
                      }).then((_) => reload()),
                    ),
                    ListTile(
                      title: const Text('Jadval'),
                      subtitle: Text(_scheduleText(menu['schedule_json'] as Json?)),
                      trailing: const Icon(Icons.schedule),
                      onTap: () => _schedule(menu, reload),
                    ),
                    ListTile(
                      title: const Text('Menyuni oʻchirish'),
                      trailing: const Icon(Icons.delete_outline),
                      onTap: () => _delete('menus', 'menu', menu['id'] as String, 'Menyu butunlay oʻchirilsinmi?', reload),
                    ),
                  ],
                ),
              ),
              SectionTitle(
                'Kategoriyalar',
                trailing: TextButton(onPressed: () => _addCategory(menu['id'] as String, categories.length, reload), child: const Text('Qoʻshish')),
              ),
              for (final (index, category) in categories.indexed)
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        title: Text(data.text(category['id'], 'name')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(tooltip: 'Yuqoriga', icon: const Icon(Icons.arrow_upward), onPressed: () => _move('menu_categories', categories, index, -1, reload)),
                            IconButton(tooltip: 'Pastga', icon: const Icon(Icons.arrow_downward), onPressed: () => _move('menu_categories', categories, index, 1, reload)),
                            IconButton(tooltip: 'Tarjima', icon: const Icon(Icons.translate), onPressed: () => _editCategory(category, data, reload)),
                            IconButton(tooltip: 'Oʻchirish', icon: const Icon(Icons.delete_outline), onPressed: () => _delete('menu_categories', 'menu_category', category['id'] as String, 'Kategoriya oʻchirilsinmi?', reload)),
                          ],
                        ),
                      ),
                      for (final (itemIndex, item) in data.itemsOf(category['id']).indexed)
                        ListTile(
                          leading: item['photo_url'] == null ? null : Image.network(item['photo_url'] as String, width: 44, height: 44, fit: BoxFit.cover),
                          title: Text(data.text(item['id'], 'name')),
                          subtitle: Text(formatMoney(item['price_uzs'] as num)),
                          onTap: () => _editItem(category['id'] as String, item, data, data.itemsOf(category['id']).length, reload),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(tooltip: 'Yuqoriga', icon: const Icon(Icons.arrow_upward), onPressed: () => _move('menu_items', data.itemsOf(category['id']), itemIndex, -1, reload)),
                              // B-12: "tugagan" belgisi bir bosishda saytga o'tadi.
                              Switch(
                                value: item['available'] as bool,
                                onChanged: (value) => attempt(context, () async {
                                  await db.from('menu_items').update({'available': value}).eq('id', item['id'] as String);
                                }).then((_) => reload()),
                              ),
                            ],
                          ),
                        ),
                      TextButton(
                        onPressed: () => _editItem(category['id'] as String, null, data, data.itemsOf(category['id']).length, reload),
                        child: const Text('Taom qoʻshish'),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  String _scheduleText(Json? schedule) {
    if (schedule == null) return 'Doim koʻrinadi';
    final days = (schedule['days'] as List?)?.cast<int>();
    return '${days == null ? 'Har kuni' : days.map((d) => _dayNames[d]).join(', ')}, ${schedule['from']}–${schedule['to']}';
  }

  Future<void> _editCategory(Json category, _MenuData data, VoidCallback reload) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TranslationsDialog(type: 'menu_category', id: category['id'] as String, data: data, fields: const {'name': 'Nomi'}),
    );
    reload();
  }

  Future<void> _editItem(String categoryId, Json? item, _MenuData data, int position, VoidCallback reload) async {
    await showDialog<void>(context: context, builder: (_) => _ItemDialog(categoryId: categoryId, item: item, data: data, position: position));
    reload();
  }
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog(this.schedule);

  final Json? schedule;

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late final Set<int> _days = {...?(widget.schedule?['days'] as List?)?.cast<int>()};
  late final _from = TextEditingController(text: widget.schedule?['from'] as String? ?? '08:00');
  late final _to = TextEditingController(text: widget.schedule?['to'] as String? ?? '12:00');

  @override
  Widget build(BuildContext context) {
    final time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    return AlertDialog(
      title: const Text('Menyu jadvali'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 4,
            children: [
              for (final (index, name) in _dayNames.indexed)
                FilterChip(
                  label: Text(name),
                  selected: _days.contains(index),
                  onSelected: (on) => setState(() => on ? _days.add(index) : _days.remove(index)),
                ),
            ],
          ),
          const Text('Kun tanlanmasa, har kuni koʻrinadi.'),
          TextField(controller: _from, decoration: const InputDecoration(labelText: 'Boshlanishi (SS:DD)')),
          TextField(controller: _to, decoration: const InputDecoration(labelText: 'Tugashi (SS:DD)')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, 'clear'), child: const Text('Jadvalni olib tashlash')),
        FilledButton(
          onPressed: () {
            if (!time.hasMatch(_from.text) || !time.hasMatch(_to.text)) return;
            Navigator.pop<Object>(context, <String, dynamic>{
              if (_days.isNotEmpty) 'days': (_days.toList()..sort()),
              'from': _from.text,
              'to': _to.text,
            });
          },
          child: const Text('Saqlash'),
        ),
      ],
    );
  }
}

class _DraftDialog extends StatelessWidget {
  const _DraftDialog(this.draft);

  final Json draft;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI qoralamasini tekshiring'),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final category in (draft['categories'] as List).cast<Json>()) ...[
              Padding(padding: const EdgeInsets.only(top: 12), child: Text(category['name'] as String, style: Theme.of(context).textTheme.titleSmall)),
              for (final item in (category['items'] as List).cast<Json>())
                ListTile(dense: true, title: Text(item['name'] as String), trailing: Text(formatMoney(item['price_uzs'] as num))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Bekor qilish')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Qoralama sifatida qoʻshish')),
      ],
    );
  }
}

/// Tarjimalar: AI faqat maydonlarni to'ldiradi, saqlashni egasi bosadi (B-14).
class _TranslationFields extends StatelessWidget {
  const _TranslationFields({required this.source, required this.controllers});

  final TextEditingController source;
  final Map<String, TextEditingController> controllers;

  Future<void> _draft(BuildContext context) async {
    await attempt(context, () async {
      final result = await callApi('/ai/translate', {'business_id': biz.id, 'text': source.text});
      final draft = result['draft'] as Json;
      controllers['uz-Cyrl']?.text = draft['uz_cyrl'] as String;
      controllers['ru']?.text = draft['ru'] as String;
      controllers['en']?.text = draft['en'] as String;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in _locales.entries)
          TextField(controller: controllers[entry.key], decoration: InputDecoration(labelText: entry.value)),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _draft(context), child: const Text('AI qoralama'))),
      ],
    );
  }
}

class _TranslationsDialog extends StatefulWidget {
  const _TranslationsDialog({required this.type, required this.id, required this.data, required this.fields});

  final String type;
  final String id;
  final _MenuData data;
  final Map<String, String> fields;

  @override
  State<_TranslationsDialog> createState() => _TranslationsDialogState();
}

class _TranslationsDialogState extends State<_TranslationsDialog> {
  late final _source = TextEditingController(text: widget.data.text(widget.id, 'name'));
  late final _controllers = {
    for (final locale in _locales.keys) locale: TextEditingController(text: widget.data.text(widget.id, 'name', locale)),
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nomi va tarjimalari'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: _source, decoration: const InputDecoration(labelText: 'Oʻzbekcha')),
              _TranslationFields(source: _source, controllers: _controllers),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
        FilledButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            final saved = await attempt(context, () async {
              await saveTranslation(widget.type, widget.id, 'name', 'uz', _source.text);
              for (final entry in _controllers.entries) {
                await saveTranslation(widget.type, widget.id, 'name', entry.key, entry.value.text);
              }
            });
            if (saved) navigator.pop();
          },
          child: const Text('Saqlash'),
        ),
      ],
    );
  }
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.categoryId, required this.item, required this.data, required this.position});

  final String categoryId;
  final Json? item;
  final _MenuData data;
  final int position;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late final Object? _id = widget.item?['id'];
  late final _name = TextEditingController(text: widget.data.text(_id, 'name'));
  late final _description = TextEditingController(text: widget.data.text(_id, 'description'));
  late final _portion = TextEditingController(text: widget.data.text(_id, 'portion'));
  late final _price = TextEditingController(text: '${widget.item?['price_uzs'] ?? ''}');
  late final _tags = TextEditingController(text: (widget.item?['tags'] as List? ?? const []).join(', '));
  late String? _photo = widget.item?['photo_url'] as String?;
  late final _translations = {
    for (final locale in _locales.keys) locale: TextEditingController(text: widget.data.text(_id, 'name', locale)),
  };

  Future<void> _save() async {
    final price = int.tryParse(_price.text.replaceAll(' ', ''));
    if (_name.text.trim().isEmpty || price == null || price < 0) {
      showMessage(context, 'Nom va narxni kiriting.');
      return;
    }
    final navigator = Navigator.of(context);
    final saved = await attempt(context, () async {
      final fields = {
        'price_uzs': price,
        'photo_url': _photo,
        'tags': _tags.text.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList(),
      };
      final String id;
      if (_id == null) {
        final row = await db.from('menu_items').insert({
          ...fields,
          'business_id': biz.id,
          'category_id': widget.categoryId,
          'position': widget.position,
        }).select().single();
        id = row['id'] as String;
      } else {
        id = _id as String;
        await db.from('menu_items').update(fields).eq('id', id);
      }
      await saveTranslation('menu_item', id, 'name', 'uz', _name.text);
      await saveTranslation('menu_item', id, 'description', 'uz', _description.text);
      await saveTranslation('menu_item', id, 'portion', 'uz', _portion.text);
      for (final entry in _translations.entries) {
        await saveTranslation('menu_item', id, 'name', entry.key, entry.value.text);
      }
    });
    if (saved) navigator.pop();
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final deleted = await attempt(context, () async {
      await db.from('menu_items').delete().eq('id', _id as String);
      await db.from('translations').delete().match({'entity_type': 'menu_item', 'entity_id': _id});
    });
    if (deleted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_id == null ? 'Yangi taom' : 'Taomni tahrirlash'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nomi (oʻzbekcha)')),
              TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Tavsif')),
              TextField(controller: _portion, decoration: const InputDecoration(labelText: 'Porsiya', hintText: '300 g')),
              TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Narx, soʻm')),
              TextField(controller: _tags, decoration: const InputDecoration(labelText: 'Belgilar', hintText: 'achchiq, vegetarian')),
              const SizedBox(height: 8),
              if (_photo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(aspectRatio: 16 / 10, child: Image.network(_photo!, fit: BoxFit.cover)),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => attempt(context, () async {
                        final url = await uploadImage('item');
                        if (url != null) setState(() => _photo = url);
                      }),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(_photo == null ? 'Rasm qoʻshish' : 'Rasmni almashtirish'),
                    ),
                  ),
                  if (_photo != null)
                    IconButton(tooltip: 'Rasmni olib tashlash', onPressed: () => setState(() => _photo = null), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              _TranslationFields(source: _name, controllers: _translations),
            ],
          ),
        ),
      ),
      actions: [
        if (_id != null) TextButton(onPressed: _delete, child: const Text('Oʻchirish')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
        FilledButton(onPressed: _save, child: const Text('Saqlash')),
      ],
    );
  }
}
