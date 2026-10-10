import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as io;
import 'package:sixora/src/data/app_controller.dart';
import 'package:sixora/src/data/local_server.dart';
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

  test('moving to a new account on a server', () async {
    await startLocal();
    final r = await c.moveToServer(
      server: remoteUrl,
      serverName: 'Test',
      username: 'anna',
      password: 'server-master-password',
      create: true,
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
