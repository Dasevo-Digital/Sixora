// End-to-end test of the real app against a fresh, empty Sixora server:
//
//   (cd server && SIXORA_DATA_DIR=$(mktemp -d) SIXORA_PORT=18081 dart run bin/server.dart)
//   flutter test integration_test -d macos --dart-define=SIXORA_ENV=test \
//     --dart-define=SIXORA_TEST_SERVER=http://127.0.0.1:18081
//
// SIXORA_ENV=test keeps the app's data and keystore entry apart from the
// real app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sixora/src/app.dart';
import 'package:sixora/src/data/app_controller.dart';
import 'package:sixora/src/environment.dart';
import 'package:sixora/src/widgets/otp_tile.dart';
import 'package:sixora_core/sixora_core.dart';

const _server = String.fromEnvironment(
  'SIXORA_TEST_SERVER',
  defaultValue: 'http://127.0.0.1:18081',
);
const _password = 'test-passwort-123';
const _secret = 'JBSWY3DPEHPK3PXP';

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>();
  throw TestFailure('Nicht gefunden: $finder\nSichtbar: ${texts.join(' | ')}');
}

Finder _field(String label) => find.widgetWithText(TextField, label);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('register, add an account, lock and unlock', (tester) async {
    expect(
      AppEnv.name,
      'test',
      reason: 'nur mit --dart-define=SIXORA_ENV=test',
    );
    final controller = await AppController.create();
    if (controller.cached != null) await controller.logout(notice: '');
    controller.notice = null;
    await tester.pumpWidget(SixoraApp(controller: controller));

    // Connect to the empty server: the first account becomes admin.
    await tester.enterText(_field('Server-Adresse'), _server);
    await tester.tap(find.text('Verbinden'));
    await _pumpUntil(
      tester,
      find.textContaining('Das erste Konto wird Administrator'),
    );

    final user = 'alice${DateTime.now().millisecondsSinceEpoch % 100000}';
    await tester.enterText(_field('Benutzername'), user);
    await tester.enterText(_field('Master-Passwort'), _password);
    await tester.enterText(_field('Master-Passwort wiederholen'), _password);
    await tester.tap(find.widgetWithText(FilledButton, 'Konto erstellen'));

    // The recovery key has to be confirmed before the vault opens.
    await _pumpUntil(
      tester,
      find.text('Ich habe den Schlüssel sicher aufbewahrt.'),
    );
    expect(find.widgetWithText(FilledButton, 'Weiter'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Weiter'));
    await _pumpUntil(tester, find.text('Noch keine Konten'));
    expect(controller.phase, Phase.unlocked);
    expect(controller.isAdmin, isTrue);

    // Add an account by hand.
    await tester.tap(find.text('Hinzufügen'));
    await _pumpUntil(tester, find.text('Manuell eingeben'));
    await tester.tap(find.text('Manuell eingeben'));
    await _pumpUntil(tester, _field('Dienst'));
    await tester.enterText(_field('Dienst'), 'GitHub');
    await tester.enterText(_field('Konto'), 'alice@example.org');
    await tester.enterText(_field('Geheimer Schlüssel'), 'jbsw y3dp ehpk 3pxp');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Speichern'));
    await _pumpUntil(tester, find.byType(OtpTile));
    // Let the editor's closing transition finish.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Konto hinzufügen'), findsNothing);
    expect(find.text('GitHub'), findsOneWidget);

    // The shown code is the RFC 6238 code of the secret.
    final code = Otp.generate(secret: _secret, type: OtpType.totp);
    final next = Otp.generate(
      secret: _secret,
      type: OtpType.totp,
      time: DateTime.now().add(const Duration(seconds: 2)),
    );
    expect(
      find.text(groupCode(code)).evaluate().isNotEmpty ||
          find.text(groupCode(next)).evaluate().isNotEmpty,
      isTrue,
    );

    // The server only got ciphertext.
    expect(
      controller.cached!.entries.values.single.data,
      isNot(contains('GitHub')),
    );
    expect(
      controller.cached!.entries.values.single.data,
      isNot(contains(_secret)),
    );

    // Lock and unlock with the master password.
    controller.lock();
    await _pumpUntil(tester, find.text('Gesperrt'));
    await tester.enterText(_field('Master-Passwort'), 'falsch-falsch');
    await tester.tap(find.widgetWithText(FilledButton, 'Entsperren'));
    await _pumpUntil(tester, find.text('Master-Passwort ist falsch'));
    // The field is cleared after a failed attempt; focus it again first.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(_field('Master-Passwort'));
    await tester.pump();
    await tester.enterText(_field('Master-Passwort'), _password);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Entsperren'));
    await _pumpUntil(tester, find.byType(OtpTile));
    expect(find.text('GitHub'), findsOneWidget);

    // Clean up: log out removes the local copy.
    await controller.logout();
    await _pumpUntil(tester, _field('Server-Adresse'));
  });
}
