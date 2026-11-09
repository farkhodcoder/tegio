import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tegio_core/tegio_core.dart';

void main() {
  group('StampOutcome', () {
    test('B-24: muvaffaqiyatli shtamp o\'qiladi', () {
      final outcome = StampOutcome.fromJson({
        'ok': true,
        'duplicate': false,
        'stamps': 5,
        'new_rewards': [
          {'id': 'r1', 'title': 'Somsa'},
        ],
        'available_rewards': [
          {'id': 'r1', 'title': 'Somsa'},
        ],
      });
      expect(outcome, isA<StampApplied>());
      final applied = outcome as StampApplied;
      expect(applied.stamps, 5);
      expect(applied.newRewards.single.title, 'Somsa');
    });

    test('B-25: SQL xato kodlari aniq turga aylanadi', () {
      const codes = {
        'qr_used': StampError.qrUsed,
        'qr_expired': StampError.qrExpired,
        'interval_limit': StampError.intervalLimit,
        'wrong_business': StampError.wrongBusiness,
      };
      codes.forEach((code, error) {
        final outcome = StampOutcome.fromJson({'ok': false, 'error': code});
        expect((outcome as StampRejected).error, error);
      });
    });

    test('noma\'lum xato ilovani yiqitmaydi', () {
      final outcome = StampOutcome.fromJson({'ok': false, 'error': 'yangi_xato'});
      expect((outcome as StampRejected).error, StampError.unknown);
    });

    test('B-18: keyingi urinish vaqti o\'qiladi', () {
      final outcome = StampOutcome.fromJson({
        'ok': false,
        'error': 'interval_limit',
        'retry_at': '2026-11-09T12:00:00Z',
      });
      expect((outcome as StampRejected).retryAt, DateTime.utc(2026, 11, 9, 12));
    });
  });

  group('TegioShell', () {
    final sections = [
      ShellSection(label: 'Birinchi', icon: Icons.home, builder: (_) => const Text('A sahifa')),
      ShellSection(label: 'Ikkinchi', icon: Icons.menu_book, builder: (_) => const Text('B sahifa')),
    ];

    Widget app() => MaterialApp(
      home: TegioShell(title: 'TEGIO', sections: sections),
    );

    testWidgets('keng ekranda yon paneldan almashadi', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      expect(find.text('A sahifa'), findsOneWidget);
      await tester.tap(find.text('Ikkinchi'));
      await tester.pumpAndSettle();
      expect(find.text('B sahifa'), findsOneWidget);
    });

    testWidgets('telefonda menyu orqali almashadi', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      expect(find.byType(NavigationDrawer), findsNothing);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ikkinchi'));
      await tester.pumpAndSettle();
      expect(find.text('B sahifa'), findsOneWidget);
      expect(find.byType(NavigationDrawer), findsNothing);
    });
  });
}
