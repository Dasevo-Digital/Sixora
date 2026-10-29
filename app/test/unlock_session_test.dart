import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sixora/src/data/app_controller.dart';
import 'package:sixora/src/data/local_store.dart';
import 'package:sixora/src/l10n.dart';
import 'package:sixora_core/sixora_core.dart';

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
    Future<http.Response> Function(http.Request) answer,
  ) {
    final server = Uri.parse('https://sixora.example/');
    return AppController.forTest(
      dir,
      cached: CachedAccount(
        server: server,
        serverName: 'Testserver',
        account: account,
      ),
      api: SixoraApi(server, client: MockClient(answer)),
    );
  }

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
