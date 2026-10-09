/// Shared setup of the server tests: a server on a free port with an
/// in-memory database, and registered, unlocked test users.
library;

import 'dart:io';

import 'package:shelf/shelf_io.dart' as io;
import 'package:sixora_core/sixora_core.dart';
import 'package:sixora_server/sixora_server.dart';

const testKdf = KdfParams(memoryKiB: 19456, iterations: 2);
const testDevice = DeviceInfo(name: 'Testgerät', platform: 'test');

class Harness {
  late HttpServer server;
  late SixoraServerApp app;
  late Uri url;

  Future<void> start({
    Registration registration = Registration.invite,
    bool trustProxy = false,
    String serverName = 'Sixora',
  }) async {
    app = SixoraServerApp(
      db: openSixoraDatabase(':memory:'),
      registration: registration,
      trustProxy: trustProxy,
      serverName: serverName,
    );
    server = await io.serve(
      app.handler,
      InternetAddress.loopbackIPv4,
      0,
      poweredByHeader: null,
    );
    url = Uri.parse('http://127.0.0.1:${server.port}/');
  }

  Future<void> stop() async {
    await server.close(force: true);
    app.db.close();
  }

  SixoraApi api() => SixoraApi(url);
}

/// A logged-in, unlocked test user.
class TestUser {
  TestUser(this.api, this.account, this.keys, this.password, this.recoveryKey);
  final SixoraApi api;
  final AccountBundle account;
  final UnlockedKeys keys;
  final String password;
  final String recoveryKey;
  final vaultKeys = <String, List<int>>{};

  static Future<TestUser> register(
    Harness h,
    String name, {
    String? invite,
  }) async {
    final password = 'pw-$name';
    final created = await NewAccount.create(
      username: name,
      password: password,
      kdf: testKdf,
    );
    final api = h.api();
    final r = await api.register({
      ...created.body,
      'device': testDevice.toJson(),
      'inviteCode': ?invite,
    });
    final keys = await UnlockedKeys.unlock(r.account, created.kek);
    return TestUser(api, r.account, keys, password, created.recoveryKey);
  }

  Future<SyncResult> sync([int since = 0]) async {
    final r = await api.sync(since);
    for (final v in r.vaults) {
      vaultKeys[v.id] = await keys.openVaultKey(v);
    }
    return r;
  }

  String get personalVaultId => vaultKeys.keys.first;

  Future<EntryDto> put(
    String vaultId,
    String id,
    OtpEntry entry, {
    int base = 0,
  }) async => api.putEntry(
    id: id,
    vaultId: vaultId,
    data: await UnlockedKeys.encryptEntry(
      vaultKeys[vaultId]! as dynamic,
      vaultId,
      id,
      entry,
    ),
    baseRevision: base,
  );
}

const github = OtpEntry(
  issuer: 'GitHub',
  account: 'alice',
  secret: 'JBSWY3DPEHPK3PXP',
);
