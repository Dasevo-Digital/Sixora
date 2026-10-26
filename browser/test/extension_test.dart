import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf_io.dart' as io;
import 'package:sixora_browser/src/app_unlock.dart';
import 'package:sixora_browser/src/extension.dart';
import 'package:sixora_core/sixora_core.dart';
import 'package:sixora_server/sixora_server.dart';
import 'package:test/test.dart';

const kdf = KdfParams(memoryKiB: 19456, iterations: 2);
const password = 'master-passwort-123';

class MapStore implements Store {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async =>
      value == null ? values.remove(key) : values[key] = value;
}

/// The desktop app's side of [BrowserLink], with the account's user key.
class FakeApp implements BrowserLinkDelegate {
  FakeApp(this.server, this.userId, this.userKey);
  final Uri server;
  final String userId;
  final Uint8List userKey;
  bool approves = true;
  final paired = <String>{};
  String? pairCode;
  int approvals = 0;

  @override
  ({Uri server, String userId})? get account =>
      (server: server, userId: userId);
  @override
  bool get unlocked => true;
  @override
  bool get unlockWhileLocked => false;
  @override
  String? get method => 'Touch ID';
  @override
  bool isPaired(String publicKey) => paired.contains(publicKey);
  @override
  Future<Uint8List?> approve({required String browser}) async {
    approvals++;
    return approves ? Uint8List.fromList(userKey) : null;
  }

  @override
  Future<Uint8List?> pair({
    required String publicKey,
    required String code,
    required String browser,
  }) async {
    pairCode = code;
    if (!approves) return null;
    paired.add(publicKey);
    return Uint8List.fromList(userKey);
  }
}

/// The extension against a real server in this process.
void main() {
  late SixoraServerApp app;
  late HttpServer server;
  late Uri url;
  late SixoraApi alice;
  late UnlockedKeys keys;
  late String personal;
  late MapStore local;
  late MapStore session;
  var now = DateTime(2026, 10, 10, 12);

  SixoraExtension extension() => SixoraExtension(
    local: local,
    session: session,
    device: const DeviceInfo(name: 'Firefox · macOS', platform: 'browser'),
    clock: () => now,
  );

  Future<void> addEntry(OtpEntry entry) async {
    final id = VaultCrypto.newId();
    final vault = (await alice.sync(0)).vaults.single;
    await alice.putEntry(
      id: id,
      vaultId: personal,
      data: await UnlockedKeys.encryptEntry(
        await keys.openVaultKey(vault),
        personal,
        id,
        entry,
      ),
      baseRevision: 0,
    );
  }

  setUp(() async {
    app = SixoraServerApp(
      db: openSixoraDatabase(':memory:'),
      registration: Registration.open,
      requireSetupCode: false,
    );
    server = await io.serve(app.handler, InternetAddress.loopbackIPv4, 0);
    url = Uri.parse('http://127.0.0.1:${server.port}/');
    final created = await NewAccount.create(
      username: 'alice',
      password: password,
      kdf: kdf,
    );
    alice = SixoraApi(url);
    final r = await alice.register({
      ...created.body,
      'device': const DeviceInfo(name: 'Mac', platform: 'macos').toJson(),
    });
    keys = await UnlockedKeys.unlock(r.account, created.kek);
    personal = (created.body['personalVault']! as Map)['id']! as String;
    await addEntry(
      const OtpEntry(
        issuer: 'GitHub',
        account: 'alice',
        secret: 'JBSWY3DPEHPK3PXP',
      ),
    );
    await addEntry(
      const OtpEntry(
        issuer: 'Zähler',
        account: '',
        secret: 'GEZDGNBVGY3TQOJQ',
        type: OtpType.hotp,
      ),
    );
    local = MapStore();
    session = MapStore();
  });

  tearDown(() async {
    alice.close();
    await server.close(force: true);
    app.db.close();
  });

  List<String> issuers(SixoraExtension e) => [
    for (final c in e.codes) c.entry.issuer,
  ];

  test('sign in, codes, and the next popup is still unlocked', () async {
    final e = extension();
    await e.load();
    expect(e.stage, Stage.setup);
    await e.signIn(
      SixoraExtension.parseAddress(url.toString()),
      'alice',
      password,
    );
    expect(e.stage, Stage.unlocked);
    // HOTP is left out: its counter would have to move on the server.
    expect(issuers(e), ['GitHub']);
    expect(
      e.codes.single.entry.code(now),
      Otp.generate(secret: 'JBSWY3DPEHPK3PXP', type: OtpType.totp, time: now),
    );

    // The browser profile holds ciphertext only: no secret, no token.
    final stored = local.values['account']!;
    expect(stored, isNot(contains('JBSWY3DPEHPK3PXP')));
    expect(stored, isNot(contains('GitHub')));
    expect(stored, isNot(contains(alice.token!)));

    // The next popup opens unlocked from storage.session.
    now = now.add(const Duration(minutes: 10));
    final next = extension();
    await next.load();
    expect(next.stage, Stage.unlocked);
    expect(issuers(next), ['GitHub']);

    // After the auto-lock time it asks for the password again.
    now = now.add(const Duration(minutes: 16));
    final later = extension();
    await later.load();
    expect(later.stage, Stage.locked);
    await expectLater(
      later.unlock('falsch'),
      throwsA(
        isA<ExtensionError>().having((e) => e.code, 'code', 'wrongPassword'),
      ),
    );
    await later.unlock(password);
    expect(issuers(later), ['GitHub']);
  });

  test('sync brings changes; the session shows up in the apps', () async {
    final e = extension();
    await e.signIn(url, 'alice', password);
    await addEntry(
      const OtpEntry(
        issuer: 'GitLab',
        account: 'alice',
        secret: 'GEZDGNBVGY3TQOJQ',
      ),
    );
    await e.sync();
    expect(issuers(e), ['GitHub', 'GitLab']);
    final sessions = await alice.sessions();
    expect(sessions.map((s) => s.deviceName), contains('Firefox · macOS'));
  });

  test('signing out ends the session on the server', () async {
    final e = extension();
    await e.signIn(url, 'alice', password);
    expect((await alice.sessions()), hasLength(2));
    await e.signOut();
    expect(e.stage, Stage.setup);
    expect(local.values, isNot(contains('account')));
    expect(session.values, isEmpty);
    expect((await alice.sessions()), hasLength(1));
  });

  test('a password changed in the app ends the extension session', () async {
    final e = extension();
    await e.signIn(url, 'alice', password);
    await e.lock();
    final current = await derivePasswordKeysAsync(
      password,
      e.stored!.account.salt,
      kdf,
    );
    await alice.changePassword({
      'authKey': current.authKeyB64,
      ...await rewrapForNewPassword(
        userId: e.stored!.account.id,
        userKey: keys.userKey,
        newPassword: 'neues-passwort-456',
        kdf: kdf,
      ),
    });
    await expectLater(
      e.unlock('neues-passwort-456'),
      throwsA(
        isA<ExtensionError>().having((e) => e.code, 'code', 'passwordChanged'),
      ),
    );
    expect(e.stage, Stage.setup);
    expect(e.signedOutRemotely, isTrue);
  });

  test('addresses and device names', () {
    expect(
      SixoraExtension.parseAddress('sixora.example.org').toString(),
      'https://sixora.example.org/',
    );
    expect(
      SixoraExtension.parseAddress('http://192.168.1.5:8080').toString(),
      'http://192.168.1.5:8080/',
    );
    expect(
      () => SixoraExtension.parseAddress('http://sixora.example.org'),
      throwsA(isA<ExtensionError>()),
    );
    String name(String ua, {bool brave = false}) =>
        browserDevice(ua, brave: brave).name;
    const mac = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)';
    expect(name('$mac Gecko/20100101 Firefox/157.0'), 'Firefox · macOS');
    expect(
      name('$mac AppleWebKit/537.36 Chrome/152.0 Safari/537.36 OPR/136.0'),
      'Opera · macOS',
    );
    expect(
      name(
        'Mozilla/5.0 (Windows NT 10.0) Chrome/152.0 Safari/537.36 Edg/152.0',
      ),
      'Edge · Windows',
    );
    expect(
      name('$mac AppleWebKit/605.1.15 Version/27.0 Safari/605.1.15'),
      'Safari · macOS',
    );
    expect(
      name(
        'Mozilla/5.0 (X11; Linux x86_64) Chrome/152.0 Safari/537.36',
        brave: true,
      ),
      'Brave · Linux',
    );
  });

  group('unlocking with the desktop app', () {
    late FakeApp fake;
    late BrowserLinkHost host;

    /// Like background.js: the answer also goes to storage.session.
    Future<Map<String, Object?>> ask(
      Map<String, Object?> request, {
      required Duration timeout,
      String? keep,
    }) async {
      final reply = await host.handle(request);
      if (keep != null) await session.write(keep, jsonEncode(reply));
      return reply;
    }

    Future<SixoraExtension> signedInAndLocked() async {
      final e = extension();
      await e.load();
      await e.signIn(url, 'alice', password);
      await e.lock();
      fake = FakeApp(url, e.stored!.account.id, keys.userKey);
      host = BrowserLinkHost(fake, version: 'test');
      return e;
    }

    test('connected once, then Touch ID unlocks the extension', () async {
      final e = await signedInAndLocked();
      final unlock = AppUnlock(e, ask, browser: 'Firefox');
      var status = (await unlock.status())!;
      expect(status.paired, isFalse);
      expect(status.method, 'Touch ID');
      final code = await unlock.code();
      await unlock.unlock();
      expect(fake.pairCode, code);
      expect(fake.approvals, 0);
      expect(e.stage, Stage.unlocked);
      expect(issuers(e), contains('GitHub'));
      // Nothing of the request stays behind.
      expect(session.values.keys, ['unlocked']);

      await e.lock();
      status = (await unlock.status())!;
      expect(status.paired, isTrue);
      expect(status.ready, isTrue);
      await unlock.unlock();
      expect(fake.approvals, 1);
      expect(e.stage, Stage.unlocked);
    });

    test('an answer after the popup closed unlocks the next one', () async {
      final e = await signedInAndLocked();
      // The popup closes while Touch ID is up: its request never returns,
      // but background.js keeps the answer.
      final closing = AppUnlock(e, (request, {required timeout, keep}) async {
        await ask(request, timeout: timeout, keep: keep);
        return Completer<Map<String, Object?>>().future;
      }, browser: 'Opera');
      unawaited(closing.unlock());
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final next = extension();
      await next.load();
      expect(next.stage, Stage.locked);
      expect(await AppUnlock(next, ask, browser: 'Opera').resume(), isTrue);
      expect(next.stage, Stage.unlocked);
    });

    test('declined, another account, no app, signed out', () async {
      final e = await signedInAndLocked();
      fake.approves = false;
      final unlock = AppUnlock(e, ask, browser: 'Opera');
      await expectLater(
        unlock.unlock(),
        throwsA(
          isA<ExtensionError>().having((x) => x.code, 'code', 'app_denied'),
        ),
      );
      expect(e.stage, Stage.locked);
      expect(fake.paired, isEmpty);
      // Not asked again on its own.
      expect(await unlock.declined, isTrue);

      host = BrowserLinkHost(
        FakeApp(url, 'someone-else', keys.userKey),
        version: 'test',
      );
      expect(await unlock.status(), isNull);

      final noApp = AppUnlock(
        e,
        (request, {required timeout, keep}) async => {'error': 'not_running'},
        browser: 'Opera',
      );
      expect(await noApp.status(), isNull);
      await expectLater(
        noApp.unlock(),
        throwsA(
          isA<ExtensionError>().having(
            (x) => x.code,
            'code',
            'app_not_running',
          ),
        ),
      );

      // Signing out forgets the key; the next account connects anew.
      expect(await local.read(SixoraExtension.linkKeyEntry), isNotNull);
      await e.signOut();
      expect(await local.read(SixoraExtension.linkKeyEntry), isNull);
    });
  });
}
