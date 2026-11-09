import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;
import 'package:tegio_core/tegio_core.dart';

class _CenteredForm extends StatelessWidget {
  const _CenteredForm({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: children),
        ),
      ),
    );
  }
}

/// Kirish faqat taklif bilan yaratilgan hisoblar uchun (P-27).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  Future<void> _submit() => attempt(context, () async {
    await db.auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
  });

  @override
  Widget build(BuildContext context) {
    return _CenteredForm(
      children: [
        Text('${TegioBrand.name} Admin', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 12),
        TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Parol'), onSubmitted: (_) => _submit()),
        const SizedBox(height: 16),
        FilledButton(onPressed: _submit, child: const Text('Kirish')),
      ],
    );
  }
}

/// Majburiy 2FA (P-28): birinchi kirishda ulanadi, keyin har safar so'raladi.
class MfaPage extends StatefulWidget {
  const MfaPage({super.key});

  @override
  State<MfaPage> createState() => _MfaPageState();
}

class _MfaPageState extends State<MfaPage> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  late final Future<_Factor> _factor = _prepare();

  Future<_Factor> _prepare() async {
    final factors = await db.auth.mfa.listFactors();
    if (factors.totp.isNotEmpty) return _Factor(factors.totp.first.id);
    final enrolled = await db.auth.mfa.enroll(
      issuer: TegioBrand.name,
      friendlyName: 'admin-${DateTime.now().millisecondsSinceEpoch}',
    );
    return _Factor(enrolled.id, uri: enrolled.totp?.uri, secret: enrolled.totp?.secret);
  }

  Future<void> _verify(_Factor factor) => attempt(context, () async {
    if (_password.text.isNotEmpty) await db.auth.updateUser(UserAttributes(password: _password.text));
    await db.auth.mfa.challengeAndVerify(factorId: factor.id, code: _code.text.trim());
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadView<_Factor>(
        load: () => _factor,
        builder: (context, factor, _) => _CenteredForm(
          children: [
            Text('Ikki bosqichli kirish', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            if (factor.uri != null) ...[
              const Text('Authenticator ilovasida QR kodni skanerlang:'),
              const SizedBox(height: 12),
              Center(child: QrImageView(data: factor.uri!, size: 200, backgroundColor: Colors.white)),
              SelectableText('Kalit: ${factor.secret}'),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Yangi parol', helperText: 'Taklif havolasi orqali kelgan boʻlsangiz, parol oʻrnating'),
              ),
            ],
            const SizedBox(height: 12),
            TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 6, autofocus: true, decoration: const InputDecoration(labelText: '6 xonali kod'), onSubmitted: (_) => _verify(factor)),
            FilledButton(onPressed: () => _verify(factor), child: const Text('Tasdiqlash')),
            TextButton(onPressed: db.auth.signOut, child: const Text('Chiqish')),
          ],
        ),
      ),
    );
  }
}

class _Factor {
  const _Factor(this.id, {this.uri, this.secret});

  final String id;
  final String? uri;
  final String? secret;
}

class NoAccessPage extends StatelessWidget {
  const NoAccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Bu hisobda admin huquqi yoʻq.'),
          TextButton(onPressed: db.auth.signOut, child: const Text('Chiqish')),
        ],
      ),
    );
  }
}
