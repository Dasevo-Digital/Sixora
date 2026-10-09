import 'package:sixora_core/sixora_core.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// The signed-in account: password, recovery, sign-ins, trusted keys.
void main() {
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.start();
  });
  tearDown(() => h.stop());

  test('password change, sessions and recovery key', () async {
    final alice = await TestUser.register(h, 'alice');
    final pre = await h.api().prelogin('alice');
    final old = VaultCrypto.derivePasswordKeys(
      alice.password,
      pre.salt,
      testKdf,
    );
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
        kdf: testKdf,
      ),
    });
    // The other device was logged out, this one stays.
    await expectLater(
      other.sync(0),
      throwsA(isA<ApiException>().having((e) => e.unauthorized, '401', true)),
    );
    expect(await alice.api.sessions(), hasLength(1));
    final account = await alice.api.account();
    final fresh = VaultCrypto.derivePasswordKeys('neu', account.salt, testKdf);
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
        kdf: testKdf,
      ),
      'newRecoveryWrappedUserKey': newRecovery.wrapped,
      'newRecoveryAuth': newRecovery.auth,
      'device': testDevice.toJson(),
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

  test('a new sign-in wakes the other devices and shows in sync', () async {
    final alice = await TestUser.register(h, 'alice');
    final first = await alice.sync();
    expect(first.sessions, hasLength(1));
    expect(first.sessions!.single.current, isTrue);

    final pending = alice.api.sync(
      first.cursor,
      wait: const Duration(seconds: 20),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final watch = Stopwatch()..start();
    final pre = await h.api().prelogin('alice');
    final keys = VaultCrypto.derivePasswordKeys(
      alice.password,
      pre.salt,
      KdfParams.fromJson(pre.kdf),
    );
    final other = h.api();
    await other.login(
      username: 'alice',
      authKey: keys.authKeyB64,
      device: const DeviceInfo(name: 'Fremder Rechner', platform: 'linux'),
    );
    final woke = await pending;
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    expect(woke.sessions, hasLength(2));
    final stranger = woke.sessions!.singleWhere((s) => !s.current);
    expect(stranger.deviceName, 'Fremder Rechner');
    expect(stranger.platform, 'linux');

    // Signing it out reaches the others as well.
    await alice.api.revokeSession(stranger.id);
    final after = await alice.api.sync(woke.cursor);
    expect(after.sessions, hasLength(1));
  });

  test(
    'trusted keys: per account, versioned, never readable by others',
    () async {
      final alice = await TestUser.register(h, 'alice');
      final invite = await alice.api.adminCreateInvite();
      final bob = await TestUser.register(h, 'bob', invite: invite.code);
      final empty = await alice.api.contacts();
      expect(empty.data, isEmpty);
      expect(empty.revision, 0);

      final data = await TrustedKeys.encrypt(
        alice.keys.userKey,
        alice.account.id,
        {bob.account.id: bob.account.publicKey},
      );
      expect(await alice.api.putContacts(data, baseRevision: 0), 1);
      // A second device with the old revision has to merge first.
      await expectLater(
        alice.api.putContacts(data, baseRevision: 0),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'conflict')),
      );
      final stored = await alice.api.contacts();
      expect(stored.revision, 1);
      expect(
        await TrustedKeys.decrypt(
          alice.keys.userKey,
          alice.account.id,
          stored.data,
        ),
        {bob.account.id: bob.account.publicKey},
      );
      // Bob sees only his own (empty) list.
      expect((await bob.api.contacts()).data, isEmpty);
    },
  );
}
