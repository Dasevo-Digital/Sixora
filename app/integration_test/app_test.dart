// End-to-end test of the real app against a fresh, empty Sixora server:
//
//   (cd server && SIXORA_DATA_DIR=$(mktemp -d) SIXORA_PORT=18081 dart run bin/server.dart)
//   flutter test integration_test -d macos --dart-define=SIXORA_ENV=test \
//     --dart-define=SIXORA_TEST_SERVER=http://127.0.0.1:18081
//
// SIXORA_ENV=test keeps the app's data and keystore entry apart from the
// real app.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sixora/src/app.dart';
import 'package:sixora/src/data/app_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sixora/src/environment.dart';
import 'package:sixora/src/platform/backup_folder.dart';
import 'package:sixora/src/platform/link_inbox.dart';
import 'package:sixora/src/platform/qr_image.dart';
import 'package:sixora/src/platform/secure_clipboard.dart';
import 'package:sixora/src/widgets/otp_tile.dart';
import 'package:sixora_core/sixora_core.dart';

import '../test/qr_image_test.dart' as qr;

const _server = String.fromEnvironment(
  'SIXORA_TEST_SERVER',
  defaultValue: 'http://127.0.0.1:18081',
);
const _password = 'test-passwort-123';

/// The account of the first test, for moving the local mode there.
String? _firstUser;
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

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (condition()) return;
  }
  throw TestFailure('Bedingung nicht erfüllt');
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
    // The texts below are German.
    controller.settings.language = 'de';
    if (controller.cached != null) await controller.logout(notice: '');
    controller.notice = null;
    await tester.pumpWidget(SixoraApp(controller: controller));

    // Connect to the empty server: the first account becomes admin.
    await tester.enterText(
      _field('Server-Adresse oder Einladungslink'),
      _server,
    );
    await tester.tap(find.text('Verbinden'));
    await _pumpUntil(
      tester,
      find.textContaining('Das erste Konto wird Administrator'),
    );

    final user = 'alice${DateTime.now().millisecondsSinceEpoch % 100000}';
    _firstUser = user;
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

    // Recycle bin: delete, find it there, restore.
    final github = controller.items.single;
    await controller.deleteEntry(github);
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.items, isEmpty);
    final trash = await controller.trash();
    expect(trash.single.item.entry.issuer, 'GitHub');
    await controller.restore(trash.single);
    expect(controller.items.single.entry.issuer, 'GitHub');
    expect(await controller.trash(), isEmpty);
    await _pumpUntil(tester, find.byType(OtpTile));

    // Another device deletes it: the list follows on its own, without
    // pressing sync.
    final other = SixoraApi(
      Uri.parse(_server),
      token: controller.secrets['token'],
    );
    final restored = controller.items.single;
    await other.deleteEntry(restored.id, baseRevision: restored.revision);
    other.close();
    await _pumpUntil(
      tester,
      find.text('Noch keine Konten'),
      timeout: const Duration(seconds: 5),
    );
    await controller.restore((await controller.trash()).single);
    await _pumpUntil(tester, find.byType(OtpTile));

    // Another sign-in shows up at once; signing it out ends that session.
    final pre = await SixoraApi(Uri.parse(_server)).prelogin(user);
    final stranger = SixoraApi(Uri.parse(_server));
    await stranger.login(
      username: user,
      authKey: (await derivePasswordKeysAsync(
        _password,
        pre.salt,
        KdfParams.fromJson(pre.kdf),
      )).authKeyB64,
      device: const DeviceInfo(name: 'Testrechner', platform: 'linux'),
    );
    await _pumpUntil(
      tester,
      find.textContaining('Neue Anmeldung: Testrechner'),
      timeout: const Duration(seconds: 5),
    );
    await tester.tap(find.widgetWithText(TextButton, 'Abmelden'));
    await _pumpUntil(tester, find.widgetWithText(FilledButton, 'Abmelden'));
    await tester.tap(find.widgetWithText(FilledButton, 'Abmelden'));
    await _waitFor(tester, () => controller.unknownSessions.isEmpty);
    expect(find.textContaining('Neue Anmeldung'), findsNothing);
    await expectLater(
      stranger.sync(0),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
    stranger.close();

    // Sharing and unsharing: the vault gets a new key by itself.
    final invite = await controller.online((api) => api.adminCreateInvite());
    final bobName = 'bob${DateTime.now().millisecondsSinceEpoch % 100000}';
    final bobAccount = await NewAccount.create(
      username: bobName,
      password: 'bob-passwort-123',
      kdf: const KdfParams(memoryKiB: 19456, iterations: 2),
    );
    final bobApi = SixoraApi(Uri.parse(_server));
    await bobApi.register({
      ...bobAccount.body,
      'device': const DeviceInfo(name: 'Bob', platform: 'test').toJson(),
      'inviteCode': invite.code,
    });
    bobApi.close();
    await controller.createVault('Team');
    final team = controller.vaults.singleWhere((v) => v.name == 'Team');
    await controller.saveEntry(
      const OtpEntry(issuer: 'Teamkonto', account: '', secret: _secret),
      vaultId: team.id,
    );
    final bob = await controller.lookupUser(bobName);
    await controller.share(team, bob, VaultRole.write);
    // Bob's key is remembered, also on the server (encrypted).
    expect(controller.cached!.trustedKeys[bob.id], bob.publicKey);
    expect((await controller.online((api) => api.contacts())).revision, 1);
    // A different key for Bob (as a hostile server would send) aborts.
    controller.cached!.trustedKeys[bob.id] = controller.account!.publicKey;
    await expectLater(
      controller.share(team, bob, VaultRole.read),
      throwsA(isA<SecurityError>()),
    );
    controller.cached!.trustedKeys[bob.id] = bob.publicKey;
    expect(controller.vault(team.id)!.dto.keyVersion, 1);
    await controller.removeMember(controller.vault(team.id)!, bob.id);
    await _waitFor(
      tester,
      () => controller.vault(team.id)?.dto.keyVersion == 2,
    );
    expect(controller.vault(team.id)!.dto.rotationPending, isFalse);
    expect(controller.vault(team.id)!.key, isNot(team.key));
    expect(
      controller.items.where((i) => i.entry.issuer == 'Teamkonto'),
      hasLength(1),
    );
    expect(controller.undecryptable, 0);

    // Automatic backup into a folder; the file opens with its password.
    final folder = Directory(
      '${(await getTemporaryDirectory()).path}/sixora-sicherung-'
      '${DateTime.now().millisecondsSinceEpoch}',
    )..createSync(recursive: true);
    await controller.enableAutoBackup(
      FolderRef(folder.path, 'Test'),
      'backup-passwort-123',
    );
    final files = folder.listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    expect(files.single.path, contains('Sixora-Sicherung-'));
    final backup = await Importers.read(
      files.single.readAsStringSync(),
      password: 'backup-passwort-123',
    );
    expect(backup.entries.map((e) => e.issuer).toSet(), {
      'GitHub',
      'Teamkonto',
    });
    expect(controller.settings.backupError, isNull);
    // Reading it back like a restore finds every account.
    final verified = await controller.verifyBackup();
    expect(verified.accounts, controller.items.length);
    expect(verified.missing, isEmpty);
    expect(verified.files, 1);
    await controller.disableAutoBackup();
    folder.deleteSync(recursive: true);

    // Copying marks the code as concealed; the text arrives as usual.
    await SecureClipboard.copy('123456', expiresIn: Duration.zero);
    expect((await Clipboard.getData(Clipboard.kTextPlain))?.text, '123456');
    await Clipboard.setData(const ClipboardData(text: ''));

    // An otpauth:// link that opened the app lands in the editor.
    LinkInbox.instance.value =
        'otpauth://totp/Example:bob@example.org?secret=JBSWY3DPEHPK3PXP&issuer=Example';
    await _pumpUntil(tester, find.text('Konto hinzufügen'));
    expect(
      tester.widget<TextField>(_field('Dienst')).controller!.text,
      'Example',
    );
    expect(LinkInbox.instance.value, isNull);
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pump(const Duration(seconds: 1));

    // Clean up: log out removes the local copy.
    await controller.logout();
    await _pumpUntil(tester, _field('Server-Adresse oder Einladungslink'));
  });

  testWidgets('without a server, later moved to one', (tester) async {
    final user = _firstUser;
    if (user == null) return; // needs the account of the first test
    final controller = await AppController.create();
    controller.settings.language = 'de';
    if (controller.cached != null) await controller.logout(notice: '');
    controller.notice = null;
    AppController.deleteLocalData();
    await tester.pumpWidget(SixoraApp(controller: controller));

    await _pumpUntil(tester, find.text('Ohne Server nutzen'));
    await tester.ensureVisible(find.text('Ohne Server nutzen'));
    await tester.tap(find.text('Ohne Server nutzen'));
    await _pumpUntil(tester, find.textContaining('Lege ein Master-Passwort'));
    expect(_field('Benutzername'), findsNothing);
    await tester.enterText(_field('Master-Passwort'), _password);
    await tester.enterText(_field('Master-Passwort wiederholen'), _password);
    await tester.tap(find.widgetWithText(FilledButton, 'Konto erstellen'));
    await _pumpUntil(
      tester,
      find.text('Ich habe den Schlüssel sicher aufbewahrt.'),
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Weiter'));
    await _pumpUntil(tester, find.text('Noch keine Konten'));
    expect(controller.isLocal, isTrue);
    expect(find.textContaining('nur auf diesem Gerät'), findsOneWidget);
    await _waitFor(tester, () => controller.vaults.isNotEmpty);
    await controller.saveEntry(
      const OtpEntry(issuer: 'GitLab', account: '', secret: 'GEZDGNBVGY3TQOJQ'),
      vaultId: controller.vaults.single.id,
    );
    await _pumpUntil(tester, find.text('GitLab'));

    // Move to the server, into the account of the first test.
    await tester.tap(find.byTooltip('Einstellungen'));
    await _pumpUntil(tester, find.text('Automatisch sperren'));
    await tester.scrollUntilVisible(
      find.text('Mit Server verbinden'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Mit Server verbinden'));
    await _pumpUntil(tester, _field('Server-Adresse oder Einladungslink'));
    expect(find.text('Ohne Server nutzen'), findsNothing);
    await tester.enterText(
      _field('Server-Adresse oder Einladungslink'),
      _server,
    );
    await tester.tap(find.text('Verbinden'));
    await _pumpUntil(tester, _field('Benutzername'));
    await tester.enterText(_field('Benutzername'), user);
    await tester.enterText(_field('Master-Passwort'), _password);
    await tester.tap(find.widgetWithText(FilledButton, 'Übertragen'));
    await _pumpUntil(tester, find.text('1 Code übertragen'));
    expect(controller.isLocal, isFalse);
    expect(controller.account!.username, user);
    expect(
      controller.items.map((i) => i.entry.issuer),
      containsAll(['GitHub', 'GitLab']),
    );

    await controller.logout();
    await _pumpUntil(tester, _field('Server-Adresse oder Einladungslink'));
  });

  testWidgets('the system reads a dense transfer code from a screenshot', (
    tester,
  ) async {
    final uri = GoogleMigration.build(qr.accounts(10), batchSize: 10).single;
    final dir = await getTemporaryDirectory();
    dir.createSync(recursive: true);
    final file = File('${dir.path}/transfer.png')
      ..writeAsBytesSync(qr.screenshot(uri));
    addTearDown(() => file.deleteSync());
    // Apple Vision / ML Kit via mobile_scanner, as for picked images; Linux
    // and Windows have no system reader and use the fallback below.
    if (Platform.isMacOS || Platform.isIOS || Platform.isAndroid) {
      expect(await readQrNative(file.path), [uri]);
    }
    expect(await readQrImages([(path: file.path, bytes: file.readAsBytes)]), [
      uri,
    ]);
  });
}
