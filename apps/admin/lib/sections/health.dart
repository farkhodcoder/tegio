import 'package:flutter/material.dart';
import 'package:tegio_core/tegio_core.dart';

/// P-04: tizim holati. Kalitlarning o'zi emas, faqat ulangan-ulanmagani ko'rinadi.
class HealthSection extends StatelessWidget {
  const HealthSection({super.key});

  static const _labels = {
    'sms': ('SMS (Eskiz)', 'Mehmon va xodimlar telefon orqali kiradi. Busiz faqat sinov raqamlari ishlaydi.'),
    'click': ('Click', 'Tarif toʻlovi.'),
    'payme': ('Payme', 'Tarif toʻlovi.'),
    'telegram': ('Telegram bot', 'Yangi fikr haqida restoranga xabar.'),
    'ai': ('AI (menyu va tarjima)', 'Menyuni rasmdan oʻqish va 4 tilga tarjima.'),
  };

  @override
  Widget build(BuildContext context) {
    return LoadView<Json>(
      load: () => callApi('/admin/health'),
      builder: (context, health, reload) {
        final integrations = (health['integrations'] as Json?) ?? const {};
        final database = (health['database'] as Json?) ?? const {};
        final devMode = integrations['otp_dev_mode'] == true;
        return SectionList(
          children: [
            SectionTitle('Tizim holati', trailing: TextButton.icon(onPressed: reload, icon: const Icon(Icons.refresh), label: const Text('Yangilash'))),
            if (devMode)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: const ListTile(
                  leading: Icon(Icons.warning_amber_rounded),
                  title: Text('OTP_DEV_MODE yoqilgan'),
                  subtitle: Text('SMS kodi javobda qaytadi: istalgan raqam bilan kirish mumkin. Jonli muhitda darhol oʻchiring.'),
                ),
              ),
            _StatusTile(
              ok: database['ok'] == true,
              title: 'Maʼlumotlar bazasi',
              subtitle: database['ok'] == true ? 'Javob: ${database['ms']} ms' : 'Javob bermayapti',
            ),
            for (final entry in _labels.entries)
              _StatusTile(ok: integrations[entry.key] == true, title: entry.value.$1, subtitle: entry.value.$2),
            Text('Tekshirildi: ${formatDate(health['checked_at'])}', style: Theme.of(context).textTheme.bodySmall),
          ],
        );
      },
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.ok, required this.title, required this.subtitle});

  final bool ok;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF1E7F4F) : Theme.of(context).colorScheme.error;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(ok ? 'Ulangan' : 'Ulanmagan', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
