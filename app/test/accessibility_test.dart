import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixora/src/data/app_controller.dart';
import 'package:sixora/src/l10n.dart';
import 'package:sixora/src/screens/welcome_screen.dart';
import 'package:sixora/src/widgets/common.dart';
import 'package:sixora/src/widgets/otp_tile.dart';
import 'package:sixora_core/sixora_core.dart';

/// Screen readers and large text: what is read out, and that nothing
/// overflows at 200-300 % on a small phone.
void main() {
  late Directory dir;
  late AppController controller;
  late Ticker ticker;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('sixora-a11y');
    controller = AppController.forTest(dir);
    ticker = Ticker();
  });
  tearDown(() {
    ticker.dispose();
    dir.deleteSync(recursive: true);
  });

  Item item({String issuer = 'GitHub', OtpType type = OtpType.totp}) => Item(
    'id1',
    'vault1',
    1,
    OtpEntry(
      issuer: issuer,
      account: 'alice@example.org',
      secret: 'JBSWY3DPEHPK3PXP',
      type: type,
    ),
  );

  Future<void> show(WidgetTester tester, Item it, {double scale = 1}) async {
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: ListView(
                children: [OtpTile(item: it, ticker: ticker, onMenu: (_) {})],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the code is read digit by digit, with name and time left', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await show(tester, item());
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^GitHub, alice@example\.org, Code( \d){6}, noch \d+ Sekunden$',
        ),
      ),
      findsOneWidget,
    );
    // The buttons stay separate, with their own names.
    expect(
      tester.getSemantics(find.byIcon(Icons.more_vert)),
      isSemantics(tooltip: 'Mehr', isButton: true),
    );
    handle.dispose();
  });

  testWidgets('hidden codes are not read out', (tester) async {
    final handle = tester.ensureSemantics();
    controller.settings.hideCodes = true;
    await show(tester, item());
    expect(
      find.bySemanticsLabel('GitHub, alice@example.org, Code verborgen'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'\d{3}')), findsNothing);
    handle.dispose();
  });

  testWidgets('200-300 % text on a small phone does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final scale in [2.0, 3.0]) {
      for (final it in [
        item(),
        item(issuer: 'Ein sehr langer Dienstname GmbH & Co. KG'),
        item(type: OtpType.hotp),
        item(type: OtpType.steam),
      ]) {
        await show(tester, it, scale: scale);
        expect(
          tester.takeException(),
          isNull,
          reason: '${it.entry.issuer}, ${scale * 100} %',
        );
      }
    }
  });

  testWidgets('the welcome screen fits 200-300 % text on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final scale in [2.0, 3.0]) {
      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const WelcomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${scale * 100} %');
    }
  });

  testWidgets('read out in Spanish and English as well', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(() => useLocale(const Locale('de')));
    useLocale(const Locale('es'));
    await show(tester, item());
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^GitHub, alice@example\.org, Código( \d){6}, quedan? \d+ segundos?$',
        ),
      ),
      findsOneWidget,
    );
    useLocale(const Locale('en'));
    await show(tester, item());
    expect(
      find.bySemanticsLabel(RegExp(r'Code( \d){6}, \d+ seconds? left$')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
