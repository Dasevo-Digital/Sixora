import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as io;
import 'package:sixora_core/sixora_core.dart';
import 'package:sixora_server/sixora_server.dart';
import 'package:test/test.dart';

const _kdf = KdfParams(memoryKiB: 19456, iterations: 2);
const _device = DeviceInfo(name: 'Testgerät', platform: 'test');

class _Harness {
  late HttpServer server;
  late SixoraServerApp app;
  late Uri url;

  Future<void> start({Registration registration = Registration.invite}) async {
    app = SixoraServerApp(
      db: openSixoraDatabase(':memory:'),
      registration: registration,
    );
    server = await io.serve(app.handler, InternetAddress.loopbackIPv4, 0);
    url = Uri.parse('http://127.0.0.1:${server.port}/');
  }

  Future<void> stop() async {
    await server.close(force: true);
    app.db.close();
  }

  SixoraApi api() => SixoraApi(url);
}

/// A logged-in, unlocked test user.
class _User {
  _User(this.api, this.account, this.keys, this.password, this.recoveryKey);
  final SixoraApi api;
  final AccountBundle account;
  final UnlockedKeys keys;
  final String password;
  final String recoveryKey;
  final vaultKeys = <String, List<int>>{};

  static Future<_User> register(
    _Harness h,
    String name, {
    String? invite,
  }) async {
    final password = 'pw-$name';
    final created = await NewAccount.create(
      username: name,
      password: password,
      kdf: _kdf,
    );
    final api = h.api();
    final r = await api.register({
      ...created.body,
      'device': _device.toJson(),
      'inviteCode': ?invite,
    });
    final keys = await UnlockedKeys.unlock(r.account, created.kek);
    return _User(api, r.account, keys, password, created.recoveryKey);
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

const _github = OtpEntry(
  issuer: 'GitHub',
  account: 'alice',
  secret: 'JBSWY3DPEHPK3PXP',
);

void main() {
  late _Harness h;
  setUp(() async {
    h = _Harness();
    await h.start();
  });
  tearDown(() => h.stop());

  test('first user becomes admin, then registration needs an invite', () async {
    final info = await h.api().info();
    expect(info.hasUsers, isFalse);
    expect(info.registration, RegistrationMode.invite);

    final alice = await _User.register(h, 'alice');
    expect(alice.account.isAdmin, isTrue);
    expect((await h.api().info()).hasUsers, isTrue);

    await expectLater(
      _User.register(h, 'bob'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'invalid_invite'),
      ),
    );
    final invite = await alice.api.adminCreateInvite(note: 'Bob');
    final bob = await _User.register(
      h,
      'bob',
      invite: invite.code!.toLowerCase(),
    );
    expect(bob.account.isAdmin, isFalse);
    // Invites are single use.
    await expectLater(
      _User.register(h, 'carol', invite: invite.code),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      bob.api.adminUsers(),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
    );
  });

  test('login, wrong password and enumeration-safe prelogin', () async {
    final alice = await _User.register(h, 'alice');
    final api = h.api();
    final pre = await api.prelogin('ALICE');
    expect(pre.salt, alice.account.salt);
    final keys = VaultCrypto.derivePasswordKeys(
      alice.password,
      pre.salt,
      KdfParams.fromJson(pre.kdf),
    );
    final r = await api.login(
      username: 'Alice',
      authKey: keys.authKeyB64,
      device: _device,
    );
    expect(r.account.id, alice.account.id);
    await UnlockedKeys.unlock(r.account, keys.kek);

    final wrong = VaultCrypto.derivePasswordKeys('nope', pre.salt, _kdf);
    await expectLater(
      h.api().login(
        username: 'alice',
        authKey: wrong.authKeyB64,
        device: _device,
      ),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );

    final ghost1 = await h.api().prelogin('ghost');
    final ghost2 = await h.api().prelogin('Ghost');
    expect(ghost1.salt, ghost2.salt);
    expect(ghost1.kdf, pre.kdf);
  });

  test('brute force is throttled', () async {
    await _User.register(h, 'alice');
    final wrong = base64.encode(List.filled(32, 1));
    for (var i = 0; i < 10; i++) {
      await expectLater(
        h.api().login(username: 'alice', authKey: wrong, device: _device),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
    }
    await expectLater(
      h.api().login(username: 'alice', authKey: wrong, device: _device),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 429)),
    );
  });

  test('entries sync with revisions, conflicts and tombstones', () async {
    final alice = await _User.register(h, 'alice');
    final first = await alice.sync();
    expect(first.vaults.single.personal, isTrue);
    final vaultId = alice.personalVaultId;

    final id = VaultCrypto.newId();
    final created = await alice.put(vaultId, id, _github);
    expect(created.revision, 1);

    final afterCreate = await alice.sync(first.cursor);
    expect(afterCreate.entries.single.id, id);
    final decrypted = await UnlockedKeys.decryptEntry(
      alice.vaultKeys[vaultId]! as dynamic,
      vaultId,
      id,
      afterCreate.entries.single.data,
    );
    expect(decrypted.issuer, 'GitHub');

    final updated = await alice.put(
      vaultId,
      id,
      _github.copyWith(account: 'alice2'),
      base: 1,
    );
    expect(updated.revision, 2);
    // A second device still on revision 1 gets a conflict.
    await expectLater(
      alice.put(vaultId, id, _github, base: 1),
      throwsA(isA<ApiException>().having((e) => e.conflict, 'conflict', true)),
    );

    final deleted = await alice.api.deleteEntry(id, baseRevision: 2);
    expect(deleted.deleted, isTrue);
    final afterDelete = await alice.sync(afterCreate.cursor);
    expect(afterDelete.entries.single.deleted, isTrue);
    expect(afterDelete.entries.single.data, isEmpty);
    // A full sync no longer contains deleted entries.
    expect((await alice.sync()).entries, isEmpty);

    // Garbage and oversized data is rejected.
    await expectLater(
      alice.api.putEntry(
        id: VaultCrypto.newId(),
        vaultId: vaultId,
        data: 'kein base64',
        baseRevision: 0,
      ),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
    );
  });

  test('shared vaults: read-only member, removal', () async {
    final alice = await _User.register(h, 'alice');
    final invite = await alice.api.adminCreateInvite();
    final bob = await _User.register(h, 'bob', invite: invite.code);
    await alice.sync();

    // The personal vault cannot be shared.
    final bobUser = await alice.api.lookupUser('BOB');
    expect(bobUser.publicKey, bob.account.publicKey);
    await expectLater(
      alice.api.addMember(
        alice.personalVaultId,
        userId: bobUser.id,
        sealedKey: await VaultCrypto.seal(
          alice.vaultKeys[alice.personalVaultId]!,
          bobUser.publicKey,
        ),
        role: VaultRole.read,
      ),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'personal')),
    );

    final teamId = VaultCrypto.newId();
    final teamKey = VaultCrypto.randomBytes(32);
    await alice.api.createVault(
      id: teamId,
      encryptedName: await UnlockedKeys.encryptVaultName(
        teamKey,
        teamId,
        'Team',
      ),
      sealedKey: await VaultCrypto.seal(teamKey, alice.keys.publicKey),
    );
    final aliceSync = await alice.sync();
    final entryId = VaultCrypto.newId();
    await alice.put(teamId, entryId, _github);

    final bobFirst = await bob.sync();
    expect(bobFirst.vaults, hasLength(1));
    await alice.api.addMember(
      teamId,
      userId: bobUser.id,
      sealedKey: await VaultCrypto.seal(teamKey, bobUser.publicKey),
      role: VaultRole.read,
    );
    final bobShared = await bob.sync(bobFirst.cursor);
    expect(bobShared.resetVaults, contains(teamId));
    final team = bobShared.vaults.firstWhere((v) => v.id == teamId);
    expect(team.role, VaultRole.read);
    expect(team.ownerName, 'alice');
    expect(team.memberCount, 2);
    expect(
      await UnlockedKeys.decryptVaultName(
        bob.vaultKeys[teamId]! as dynamic,
        teamId,
        team.encryptedName,
      ),
      'Team',
    );
    final shared = bobShared.entries.singleWhere((e) => e.id == entryId);
    expect(
      (await UnlockedKeys.decryptEntry(
        bob.vaultKeys[teamId]! as dynamic,
        teamId,
        entryId,
        shared.data,
      )).secret,
      _github.secret,
    );
    await expectLater(
      bob.put(teamId, entryId, _github, base: 1),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'read_only')),
    );
    // Bob cannot touch Alice's personal vault.
    await expectLater(
      bob.api.putEntry(
        id: VaultCrypto.newId(),
        vaultId: aliceSync.vaults.first.id,
        data: base64.encode(List.filled(60, 0)),
        baseRevision: 0,
      ),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
    );

    final members = await alice.api.members(teamId);
    expect(members.map((m) => m.username), ['alice', 'bob']);
    await alice.api.removeMember(teamId, bobUser.id);
    final bobAfter = await bob.sync(bobShared.cursor);
    expect(bobAfter.vaults.map((v) => v.id), isNot(contains(teamId)));
  });

  test('password change, sessions and recovery key', () async {
    final alice = await _User.register(h, 'alice');
    final pre = await h.api().prelogin('alice');
    final old = VaultCrypto.derivePasswordKeys(alice.password, pre.salt, _kdf);
    final other = h.api();
    await other.login(
      username: 'alice',
      authKey: old.authKeyB64,
      device: const DeviceInfo(name: 'Laptop', platform: 'linux'),
    );
    final sessions = await alice.api.sessions();
    expect(sessions, hasLength(2));
    expect(sessions.where((s) => s.current), hasLength(1));

    await alice.api.changePassword({
      'authKey': old.authKeyB64,
      ...await rewrapForNewPassword(
        userId: alice.account.id,
        userKey: alice.keys.userKey,
        newPassword: 'neu',
        kdf: _kdf,
      ),
    });
    // The other device was logged out, this one stays.
    await expectLater(
      other.sync(0),
      throwsA(isA<ApiException>().having((e) => e.unauthorized, '401', true)),
    );
    expect(await alice.api.sessions(), hasLength(1));
    final account = await alice.api.account();
    final fresh = VaultCrypto.derivePasswordKeys('neu', account.salt, _kdf);
    final unlocked = await UnlockedKeys.unlock(account, fresh.kek);
    expect(unlocked.userKey, alice.keys.userKey);

    // Forgotten password: reset with the recovery key.
    final rescue = h.api();
    final recovery = VaultCrypto.recoveryKeys(alice.recoveryKey);
    final start = await rescue.recoverStart(
      username: 'alice',
      recoveryAuth: recovery.auth,
    );
    final userKey = await VaultCrypto.decrypt(
      recovery.kek,
      start.recoveryWrappedUserKey,
      aad: 'sixora-user-key|${start.userId}',
    );
    expect(userKey, alice.keys.userKey);
    final newRecovery = await newRecoveryFor(
      userId: start.userId,
      userKey: userKey,
    );
    final result = await rescue.recoverFinish({
      'username': 'alice',
      'recoveryAuth': recovery.auth,
      ...await rewrapForNewPassword(
        userId: start.userId,
        userKey: userKey,
        newPassword: 'ganz neu',
        kdf: _kdf,
      ),
      'newRecoveryWrappedUserKey': newRecovery.wrapped,
      'newRecoveryAuth': newRecovery.auth,
      'device': _device.toJson(),
    });
    expect(result.account.id, alice.account.id);
    // All earlier sessions are gone and the old recovery key is spent.
    await expectLater(
      alice.api.sync(0),
      throwsA(isA<ApiException>().having((e) => e.unauthorized, '401', true)),
    );
    await expectLater(
      h.api().recoverStart(username: 'alice', recoveryAuth: recovery.auth),
      throwsA(isA<ApiException>()),
    );
    final audit = await rescue.accountAudit();
    expect(audit.map((e) => e.event), contains('recovery_used'));
  });

  test('admin can disable users and is protected as last admin', () async {
    final alice = await _User.register(h, 'alice');
    final invite = await alice.api.adminCreateInvite();
    final bob = await _User.register(h, 'bob', invite: invite.code);
    final users = await alice.api.adminUsers();
    final bobId = users.firstWhere((u) => u.username == 'bob').id;

    await alice.api.adminUpdateUser(bobId, disabled: true);
    await expectLater(
      bob.api.sync(0),
      throwsA(isA<ApiException>().having((e) => e.unauthorized, '401', true)),
    );
    await expectLater(
      alice.api.adminUpdateUser(alice.account.id, isAdmin: false),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'self')),
    );
    final pre = await h.api().prelogin('alice');
    final keys = VaultCrypto.derivePasswordKeys(alice.password, pre.salt, _kdf);
    await expectLater(
      alice.api.deleteAccount(keys.authKeyB64),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'last_admin')),
    );
    final events = await alice.api.adminAudit();
    expect(events.map((e) => e.event), contains('admin_user_updated'));
  });

  test('closed and open registration', () async {
    await h.stop();
    h = _Harness();
    await h.start(registration: Registration.open);
    await _User.register(h, 'alice');
    await _User.register(h, 'bob');
    await h.stop();

    h = _Harness();
    await h.start(registration: Registration.closed);
    // The very first account is always possible, so a server can be set up.
    await _User.register(h, 'alice');
    await expectLater(
      _User.register(h, 'bob'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'registration_closed',
        ),
      ),
    );
  });
}
