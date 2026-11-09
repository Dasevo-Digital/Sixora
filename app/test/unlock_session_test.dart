import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sixora/src/data/app_controller.dart';
import 'package:sixora/src/data/biometric_vault.dart';
import 'package:sixora/src/data/local_store.dart';
import 'package:sixora/src/l10n.dart';
import 'package:sixora_core/sixora_core.dart';

/// Touch ID that always answers: with [key], or as declined without one.
class _Fingerprint implements BiometricVault {
  Uint8List? key;

  @override
  bool get available => true;

  @override
  Future<(BiometricResult, Uint8List?)> unlock({String? reason}) async =>
      key == null
      ? (BiometricResult.cancelled, null)
      : (BiometricResult.unlocked, Uint8List.fromList(key!));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  const password = 'test-passwort-123';
  late AccountBundle account;

  setUpAll(() async {
    final created = await NewAccount.create(
      username: 'alice',
      password: password,
      kdf: const KdfParams(memoryKiB: 19456, iterations: 2),
    );
    final body = created.body;
    account = AccountBundle(
      id: body['userId']! as String,
      username: body['username']! as String,
      isAdmin: false,
      kdf: (body['kdf']! as Map).cast<String, Object?>(),
      salt: body['salt']! as String,
      wrappedUserKey: body['wrappedUserKey']! as String,
      publicKey: body['publicKey']! as String,
      encryptedPrivateKey: body['encryptedPrivateKey']! as String,
    );
  });

  AppController controller(
    Directory dir,
    Future<http.Response> Function(http.Request) answer, {
    BiometricVault? biometrics,
  }) {
    final server = Uri.parse('https://sixora.example/');
    return AppController.forTest(
      dir,
      cached: CachedAccount(
        server: server,
        serverName: 'Testserver',
        account: account,
      ),
      api: SixoraApi(server, client: MockClient(answer)),
      biometrics: biometrics,
    );
  }

  group('a connected browser extension opens the app', () {
    late Directory dir;
    late AppController c;
    late Uint8List userKey;
    final fingerprint = _Fingerprint();

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('sixora-unlock-browser');
      c = controller(
        dir,
        (_) async => throw http.ClientException('offline'),
        biometrics: fingerprint,
      );
      await c.unlockWithPassword(password);
      userKey = c.browserSessionKey!;
      c.lock();
    });

    tearDown(() {
      c.lock();
      dir.deleteSync(recursive: true);
    });

    test('with the user key sealed to its own key', () async {
      final sealed = await VaultCrypto.seal(
        userKey,
        await c.browserLinkPublicKey,
      );
      expect(await c.unlockWithSealedUserKey(sealed), isTrue);
      expect(c.phase, Phase.unlocked);
      expect(c.browserSessionKey, userKey);
    });

    test('its key survives a restart of the app', () async {
      final first = await c.browserLinkPublicKey;
      expect(await c.browserLinkPublicKey, first);
    });

    test('not with a key that does not open the account', () async {
      final sealed = await VaultCrypto.seal(
        Uint8List(32),
        await c.browserLinkPublicKey,
      );
      expect(await c.unlockWithSealedUserKey(sealed), isFalse);
      expect(c.phase, Phase.locked);
    });

    test('not with something sealed to another key', () async {
      final other = await VaultCrypto.newKeyPair();
      final sealed = await VaultCrypto.seal(userKey, other.publicKey);
      expect(await c.unlockWithSealedUserKey(sealed), isFalse);
      expect(c.phase, Phase.locked);
    });

    test('with Touch ID, and the extension still gets its key', () async {
      fingerprint.key = userKey;
      c.settings.quickUnlock = true;
      final key = await c.approveBrowserUnlock(
        reason: 'Test',
        confirm: () async => false,
      );
      expect(key, userKey);
      expect(c.phase, Phase.unlocked);
      // The link wipes its copy after sealing; the app's stays intact.
      key!.fillRange(0, key.length, 0);
      expect(c.browserSessionKey, userKey);
    });

    test('a declined Touch ID leaves it locked', () async {
      fingerprint.key = null;
      c.settings.quickUnlock = true;
      final key = await c.approveBrowserUnlock(
        reason: 'Test',
        confirm: () async => false,
      );
      expect(key, isNull);
      expect(c.phase, Phase.locked);
    });
  });

  test('a genuine connection failure still permits offline unlock', () async {
    final dir = Directory.systemTemp.createTempSync('sixora-unlock-offline');
    addTearDown(() => dir.deleteSync(recursive: true));
    final c = controller(
      dir,
      (_) async => throw http.ClientException('offline'),
    );

    await c.unlockWithPassword(password);

    expect(c.phase, Phase.unlocked);
    expect(c.cached, isNotNull);
    expect(c.secrets['token'], isNull);
    c.lock();
  });

  for (final failure in [
    (status: 401, code: 'invalid_credentials'),
    (status: 403, code: 'disabled'),
  ]) {
    test(
      '${failure.status} ${failure.code} removes the local session',
      () async {
        final dir = Directory.systemTemp.createTempSync(
          'sixora-unlock-rejected',
        );
        addTearDown(() => dir.deleteSync(recursive: true));
        final c = controller(
          dir,
          (_) async => http.Response(
            jsonEncode({
              'error': failure.code,
              'message': 'Anmeldung abgelehnt',
            }),
            failure.status,
            headers: {'content-type': 'application/json'},
          ),
        );

        await expectLater(
          c.unlockWithPassword(password),
          throwsA(
            isA<UserError>().having((e) => e.message, 'message', t.signedOut),
          ),
        );

        expect(c.phase, Phase.setup);
        expect(c.cached, isNull);
        expect(c.secrets['token'], isNull);
        expect(c.notice, isNotEmpty);
      },
    );
  }
}
