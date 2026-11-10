import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tegio_core/tegio_core.dart';

import 'state.dart';

String normalizePhone(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 9) return '+998$digits';
  if (digits.length == 12 && digits.startsWith('998')) return '+$digits';
  return '';
}

/// Google akkaunti yoki telefon va SMS bilan kirish (B-01).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo;
  String? _devCode;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    await attempt(context, () async {
      if (_sentTo == null) {
        final phone = normalizePhone(_phone.text);
        if (phone.isEmpty) throw const TegioApiException('bad_phone');
        final result = await callApi('/guest/otp/send', {'phone': phone});
        setState(() {
          _sentTo = phone;
          _devCode = result['dev_code'] as String?;
        });
      } else {
        final result = await callApi('/guest/otp/verify', {'phone': _sentTo, 'code': _code.text.trim(), 'client': 'biz'});
        await db.auth.setSession(result['refresh_token'] as String);
      }
    });
    if (mounted) setState(() => _busy = false);
  }

  // Google'dan qaytgach sessiyani supabase_flutter manzildan o'zi oladi.
  Future<void> _google() async {
    setState(() => _busy = true);
    await attempt(context, () async {
      await db.auth.signInWithOAuth(OAuthProvider.google, redirectTo: Uri.base.origin);
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sentTo != null;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${TegioBrand.name} restoran tizimi', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                if (!sent) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : _google,
                    icon: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    label: const Text('Google orqali kirish'),
                  ),
                  const SizedBox(height: 16),
                  const Row(children: [
                    Expanded(child: Divider()),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('yoki telefon bilan')),
                    Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 16),
                ],
                if (!sent)
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefon raqami', prefixText: '+998 '),
                    onSubmitted: (_) => _submit(),
                  )
                else ...[
                  Text('$_sentTo raqamiga kod yuborildi.'),
                  if (_devCode != null) Text('Sinov kodi: $_devCode'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'SMS kod'),
                    onSubmitted: (_) => _submit(),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(onPressed: _busy ? null : _submit, child: Text(sent ? 'Kirish' : 'Kod olish')),
                if (sent) TextButton(onPressed: () => setState(() => _sentTo = null), child: const Text('Raqamni oʻzgartirish')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Biznes ochish: sozlash ustasining birinchi qadami (B-04).
class CreateBusinessPage extends StatefulWidget {
  const CreateBusinessPage({super.key});

  @override
  State<CreateBusinessPage> createState() => _CreateBusinessPageState();
}

class _CreateBusinessPageState extends State<CreateBusinessPage> {
  static final _slugPattern = RegExp(r'^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$');

  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _location = TextEditingController(text: 'Asosiy filial');
  bool _busy = false;

  Future<void> _create() async {
    final slug = _slug.text.trim().toLowerCase();
    if (_name.text.trim().isEmpty || !_slugPattern.hasMatch(slug)) {
      showMessage(context, 'Nom kiriting. Manzil faqat lotin harf, raqam va chiziqchadan iborat boʻlsin (kamida 3 belgi).');
      return;
    }
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final created = await attempt(context, () async {
      await db.rpc<dynamic>('create_business', params: {
        'p_name': _name.text.trim(),
        'p_slug': slug,
        'p_location_name': _location.text.trim().isEmpty ? 'Asosiy filial' : _location.text.trim(),
      });
      await biz.load();
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (created && navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yangi biznes'),
        actions: [IconButton(tooltip: 'Chiqish', onPressed: db.auth.signOut, icon: const Icon(Icons.logout))],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Biznesingizni oching. 30 kunlik sinov darhol boshlanadi, karta talab qilinmaydi.'),
              const SizedBox(height: 16),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Biznes nomi')),
              const SizedBox(height: 12),
              TextField(
                controller: _slug,
                decoration: const InputDecoration(labelText: 'Sahifa manzili', helperText: 'Masalan: choyxona-navruz'),
              ),
              const SizedBox(height: 12),
              TextField(controller: _location, decoration: const InputDecoration(labelText: 'Birinchi filial nomi')),
              const SizedBox(height: 20),
              FilledButton(onPressed: _busy ? null : _create, child: const Text('Davom etish')),
            ],
          ),
        ),
      ),
    );
  }
}
