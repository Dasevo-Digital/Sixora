import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as io;
import 'package:sixora/src/data/app_controller.dart';
import 'package:sixora/src/data/local_server.dart';
import 'package:sixora/src/data/local_store.dart';
import 'package:sixora_core/sixora_core.dart';
import 'package:sixora_server/sixora_server.dart';

/// Sixora without a server, and the move to a server later.
void main() {
  const password = 'local-master-password';
  late Directory dir;
  late AppController c;
  late SixoraServerApp remoteApp;
  late HttpServer remote;
  late Uri remoteUrl;

  /// The remote server is new: its first account needs the setup code.
  late String setupCode;

  final github = OtpEntry(
    issuer: 'GitHub',
    account: 'alice@example.org',
    secret: 'JBSWY3DPEHPK3PXP',
  );
  final gitlab = OtpEntry(
    issuer: 'GitLab',
    account: 'alice@example.org',
    secret: 'GEZDGNBVGY3TQOJQ',
  );

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('sixora-local');
    c = AppController.forTest(dir);
    remoteApp = SixoraServerApp(
      db: openSixoraDatabase(':memory:'),
      registration: Registration.open,
    );
    setupCode = remoteApp.newSetupCode()!;
    remote = await io.serve(remoteApp.handler, InternetAddress.loopbackIPv4, 0);
    remoteUrl = Uri.parse('http://127.0.0.1:${remote.port}/');
  });

  tearDown(() async {
    c.lock();
    LocalServer.delete();
    await remote.close(force: true);
    remoteApp.db.close();
    await _delete(dir);
  });

  /// The first sync after [AppController.enter] runs in the background.
  Future<void> vaultsLoaded(AppController c) async {
    for (var i = 0; c.vaults.isEmpty && i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// After a sign-in the accounts arrive with the first sync.
  Future<void> itemsLoaded(AppController c, int count) async {
    for (var i = 0; c.items.length < count && i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// A local account with GitHub in the personal vault and GitLab in
  /// "Arbeit".
  Future<void> startLocal() async {
    final (url, info) = await AppController.openLocal();
    expect(info.hasUsers, isFalse);
    expect(info.setupCode, isFalse);
    await c.register(
      server: url,
      serverName: info.name,
      username: LocalServer.username,
      password: password,
    );
    await c.enter();
    await vaultsLoaded(c);
    await c.saveEntry(github, vaultId: c.vaults.single.id);
    final work = await c.createVault('Arbeit');
    await c.saveEntry(gitlab, vaultId: work);
  }

  List<String> issuers() => [for (final i in c.items) i.entry.issuer]..sort();

  test('codes stay on the device, as ciphertext only', () async {
    await startLocal();
    expect(c.isLocal, isTrue);
    expect(issuers(), ['GitHub', 'GitLab']);

    // The database holds no secret and no name in plaintext.
    for (final suffix in ['', '-wal']) {
      final f = File(p.join(dir.path, 'local', 'sixora.db$suffix'));
      if (!f.existsSync()) continue;
      final text = String.fromCharCodes(f.readAsBytesSync());
      for (final secret in [
        'JBSWY3DPEHPK3PXP',
        'GEZDGNBVGY3TQOJQ',
        'GitHub',
        'Arbeit',
      ]) {
        expect(text.contains(secret), isFalse, reason: '$secret in $suffix');
      }
    }

    c.lock();
    await c.unlockWithPassword(password);
    expect(issuers(), ['GitHub', 'GitLab']);

    // Signed out, the data stays; the password opens it again.
    await c.logout();
    final (url, info) = await AppController.openLocal();
    expect(info.hasUsers, isTrue);
    await c.login(
      server: url,
      serverName: info.name,
      username: LocalServer.username,
      password: password,
    );
    await itemsLoaded(c, 2);
    expect(issuers(), ['GitHub', 'GitLab']);
  });

  test('browser extensions are connected and disconnected', () async {
    await startLocal();
    final key = (await VaultCrypto.newKeyPair()).publicKey;
    // Declined: nothing remembered, nothing handed out.
    expect(
      await c.pairBrowser(
        publicKey: key,
        browser: 'Opera',
        confirm: () async => false,
      ),
      isNull,
    );
    expect(c.isLinkedBrowser(key), isFalse);
    final userKey = await c.pairBrowser(
      publicKey: key,
      browser: 'Opera',
      confirm: () async => true,
    );
    expect(userKey, hasLength(32));
    expect(c.isLinkedBrowser(key), isTrue);
    expect(c.settings.linkedBrowsers.single.browser, 'Opera');
    await c.unlinkBrowser(key);
    expect(c.isLinkedBrowser(key), isFalse);
    // Locked: no connecting.
    c.lock();
    expect(
      await c.pairBrowser(
        publicKey: key,
        browser: 'Opera',
        confirm: () async => true,
      ),
      isNull,
    );
  });

  test('moving to a new account on a server', () async {
    await startLocal();
    final r = await c.moveToServer(
      server: remoteUrl,
      serverName: 'Test',
      username: 'anna',
      password: 'server-master-password',
      create: true,
      inviteCode: setupCode,
    );
    expect(r.moved, 2);
    expect(r.recoveryKey, isNotNull);
    expect(c.isLocal, isFalse);
    expect(c.account!.username, 'anna');
    expect(issuers(), ['GitHub', 'GitLab']);
    final gitlabVault = c.items.firstWhere((i) => i.entry.issuer == 'GitLab');
    expect(
      c.vaults.firstWhere((v) => v.id == gitlabVault.vaultId).name,
      'Arbeit',
    );
    expect(LocalServer.exists, isFalse);

    // The server has them: a fresh sign-in reads them back.
    c.lock();
    await c.logout();
    await c.login(
      server: remoteUrl,
      serverName: 'Test',
      username: 'anna',
      password: 'server-master-password',
    );
    await itemsLoaded(c, 2);
    expect(issuers(), ['GitHub', 'GitLab']);
  });

  test('an iPhone keeps passkeys without listing them', () async {
    await startLocal();
    final passkey = WebAuthn.create(
      rpId: 'github.com',
      rpName: 'GitHub',
      userHandle: 'dXNlcg',
      userName: 'alice',
      displayName: 'Alice',
    );
    final vaultId = c.items.first.vaultId;
    await c.addPasskey(passkey, vaultId: vaultId);
    await c.addPasskey(
      WebAuthn.create(
        rpId: 'gitlab.com',
        rpName: 'GitLab',
        userHandle: 'dXNlcg',
        userName: 'alice',
        displayName: 'Alice',
      ),
      vaultId: vaultId,
    );
    await c.deletePasskey(
      c.passkeys.firstWhere((p) => p.passkey.rpId == 'gitlab.com'),
    );
    expect(c.showsPasskeys, isTrue);
    expect(await c.trash(), hasLength(1));

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(c.showsPasskeys, isFalse);
    expect(await c.trash(), isEmpty);
    // Still there for backups and moves, and no "cannot be decrypted".
    expect(c.passkeys.single.passkey.privateKey, passkey.privateKey);
    expect(c.undecryptable, 0);
  });

  test('passkeys live beside the codes and move along', () async {
    await startLocal();
    final passkey = WebAuthn.create(
      rpId: 'github.com',
      rpName: 'GitHub',
      userHandle: 'dXNlcg',
      userName: 'alice',
      displayName: 'Alice',
    );
    await c.addPasskey(passkey, vaultId: c.items.first.vaultId);
    expect(c.passkeys.single.passkey.credentialId, passkey.credentialId);
    expect(c.undecryptable, 0);
    expect(issuers(), ['GitHub', 'GitLab']);
    expect(c.hasPasskey(passkey), isTrue);

    // Recycle bin, as for accounts.
    await c.deletePasskey(c.passkeys.single);
    expect(c.passkeys, isEmpty);
    final trashed = (await c.trash()).single;
    expect(trashed.entry, isNull);
    expect(trashed.name, 'GitHub');
    await c.restore(trashed);
    expect(c.passkeys.single.passkey.privateKey, passkey.privateKey);

    // Locked: the private keys are out of memory.
    c.lock();
    expect(c.passkeys, isEmpty);
    await c.unlockWithPassword(password);
    expect(c.passkeys, hasLength(1));

    // Leaving local mode must not lose it.
    final r = await c.moveToServer(
      server: remoteUrl,
      serverName: 'Test',
      username: 'anna',
      password: 'server-master-password',
      create: true,
      inviteCode: setupCode,
    );
    expect(r.moved, 3);
    expect(LocalServer.exists, isFalse);
    c.lock();
    await c.logout();
    await c.login(
      server: remoteUrl,
      serverName: 'Test',
      username: 'anna',
      password: 'server-master-password',
    );
    await itemsLoaded(c, 2);
    expect(c.passkeys.single.passkey.privateKey, passkey.privateKey);
    expect(c.undecryptable, 0);
  });

  group('the Android passkey window', () {
    PasskeyRequest request() => PasskeyRequest.fromWebAuthn(
      'https://example.com',
      jsonEncode({
        'rp': {'id': 'example.com', 'name': 'Example'},
        'user': {'id': 'dXNlcg', 'name': 'alice', 'displayName': 'Alice'},
        'challenge': 'Y2hhbGxlbmdl',
        'pubKeyCredParams': [
          {'type': 'public-key', 'alg': -7},
        ],
      }),
      create: true,
      clientDataHash: List.filled(32, 1),
    );

    test('writes to the server and leaves the files to the app', () async {
      const pw = 'server-master-password';
      await c.register(
        server: remoteUrl,
        serverName: 'Test',
        username: 'anna',
        password: pw,
        inviteCode: setupCode,
      );
      await c.enter();
      await vaultsLoaded(c);
      c.lock();
      AppController window() => AppController.forTest(
        dir,
        cached: LocalStore(dir).loadAccount(),
        passive: true,
      );
      int storedEntries() => LocalStore(dir).loadAccount()!.entries.length;
      final before = storedEntries();

      final w = window();
      await w.unlockWithPassword(pw);
      final answer = await w.createPasskeyFromWindow(
        request(),
        userVerified: true,
      );
      expect(w.passkeys.single.passkey.rpId, 'example.com');
      expect(storedEntries(), before);

      // The next window has only the old files, and asks the server.
      final next = window();
      await next.unlockWithPassword(pw);
      expect(next.passkeys, isEmpty);
      await next.refreshWindow();
      expect(next.passkeys.single.passkey.credentialId, answer['id']);
      expect(storedEntries(), before);

      // The app gets it with its next sync.
      await c.unlockWithPassword(pw);
      for (var i = 0; c.passkeys.isEmpty && i < 200; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(c.passkeys.single.passkey.credentialId, answer['id']);
      expect(c.undecryptable, 0);
    });

    test('cannot make passkeys without a server', () async {
      await startLocal();
      await expectLater(
        c.createPasskeyFromWindow(request(), userVerified: true),
        throwsA(isA<UserError>()),
      );
    });
  });

  test('moving into an existing account skips codes it has', () async {
    // Bob already keeps GitHub on the server.
    final otherDir = Directory.systemTemp.createTempSync('sixora-other');
    addTearDown(() => _delete(otherDir));
    final other = AppController.forTest(otherDir);
    await other.register(
      server: remoteUrl,
      serverName: 'Test',
      username: 'bob',
      password: 'bob-master-password',
      inviteCode: setupCode,
    );
    await other.enter();
    await vaultsLoaded(other);
    await other.saveEntry(github, vaultId: other.vaults.single.id);
    other.lock();
    LocalServer.folder = Directory(p.join(dir.path, 'local'));

    await startLocal();
    // A wrong password changes nothing.
    await expectLater(
      c.moveToServer(
        server: remoteUrl,
        serverName: 'Test',
        username: 'bob',
        password: 'wrong-password',
        create: false,
      ),
      throwsA(anything),
    );
    expect(c.isLocal, isTrue);
    expect(issuers(), ['GitHub', 'GitLab']);
    expect(LocalServer.exists, isTrue);

    final r = await c.moveToServer(
      server: remoteUrl,
      serverName: 'Test',
      username: 'bob',
      password: 'bob-master-password',
      create: false,
    );
    expect(r.moved, 1);
    expect(r.recoveryKey, isNull);
    expect(issuers(), ['GitHub', 'GitLab']);
    expect(LocalServer.exists, isFalse);
  });
}

/// Windows keeps fresh files busy for a moment (virus scanner).
Future<void> _delete(Directory dir) async {
  for (var attempt = 0; ; attempt++) {
    try {
      dir.deleteSync(recursive: true);
      return;
    } on FileSystemException {
      if (attempt >= 20) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
