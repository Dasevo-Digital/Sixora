import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixora/src/l10n.dart';
import 'package:sixora/src/screens/home_screen.dart';

void main() {
  Future<void> showMenu(
    WidgetTester tester, {
    required Size size,
    required double textScale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showAddMethodSheet(
                  context,
                  hasCamera: true,
                  screenCaptureSupported: true,
                ),
                child: Text(t.add),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(t.add));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(t.scanQrCode), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text(t.importAction), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  setUp(() => useLocale(const Locale('de')));

  testWidgets('add menu scrolls in a compact desktop window', (tester) async {
    addTearDown(tester.view.reset);
    await showMenu(tester, size: const Size(480, 380), textScale: 1);
  });

  for (final scale in [2.0, 3.0]) {
    testWidgets('add menu fits at ${(scale * 100).round()} % text', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      await showMenu(tester, size: const Size(600, 480), textScale: scale);
    });
  }
}
