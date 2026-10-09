import 'dart:convert';

import 'package:sixora_core/sixora_core.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Shared vaults, members and key rotation.
void main() {
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.start();
  });
  tearDown(() => h.stop());

  test('shared vaults: read-only member, removal', () async {
    final alice = await TestUser.register(h, 'alice');
    final invite = await alice.api.adminCreateInvite();
    final bob = await TestUser.register(h, 'bob', invite: invite.code);
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
    await alice.put(teamId, entryId, github);

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
      github.secret,
    );
    await expectLater(
      bob.put(teamId, entryId, github, base: 1),
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

  test('removing a member asks the owner to rotate the key', () async {
    final alice = await TestUser.register(h, 'alice');
    final invite = await alice.api.adminCreateInvite();
    final bob = await TestUser.register(h, 'bob', invite: invite.code);
    final invite2 = await alice.api.adminCreateInvite();
    final carol = await TestUser.register(h, 'carol', invite: invite2.code);
    await alice.sync();

    final teamId = VaultCrypto.newId();
    final oldKey = VaultCrypto.randomBytes(32);
    await alice.api.createVault(
      id: teamId,
      encryptedName: await UnlockedKeys.encryptVaultName(
        oldKey,
        teamId,
        'Team',
      ),
      sealedKey: await VaultCrypto.seal(oldKey, alice.keys.publicKey),
    );
    await alice.sync();
    final live = await alice.put(teamId, VaultCrypto.newId(), github);
    final binnedId = VaultCrypto.newId();
    final binned = await alice.put(teamId, binnedId, github);
    await alice.api.deleteEntry(binnedId, baseRevision: binned.revision);
    for (final u in [bob, carol]) {
      await alice.api.addMember(
        teamId,
        userId: u.account.id,
        sealedKey: await VaultCrypto.seal(oldKey, u.account.publicKey),
        role: VaultRole.write,
      );
    }
    final carolBefore = await carol.sync();
    final bobBefore = await bob.sync();
    expect(
      bobBefore.vaults.singleWhere((v) => v.id == teamId).rotationPending,
      isFalse,
    );

    await alice.api.removeMember(teamId, bob.account.id);
    var state = await alice.sync();
    var team = state.vaults.singleWhere((v) => v.id == teamId);
    expect(team.rotationPending, isTrue);
    expect(team.keyVersion, 1);
    // Only the owner hears about it.
    expect(
      (await carol.sync(
        carolBefore.cursor,
      )).vaults.singleWhere((v) => v.id == teamId).rotationPending,
      isFalse,
    );

    final members = await alice.api.members(teamId);
    final trash = (await alice.api.trash())
        .where((e) => e.vaultId == teamId)
        .toList();
    Future<Map<String, Object?>> body({
      List<MemberDto>? withMembers,
      int keyVersion = 1,
    }) async => (await rotateVaultKey(
      oldKey: oldKey,
      vaultId: teamId,
      keyVersion: keyVersion,
      name: 'Team',
      members: withMembers ?? members,
      entries: [live],
      trash: trash,
    )).body;

    // Leaving out a member (or listing a removed one) is refused.
    await expectLater(
      alice.api.rotateVault(teamId, await body(withMembers: [members.first])),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'conflict')),
    );
    // Only the owner rotates.
    await expectLater(
      carol.api.rotateVault(teamId, await body()),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
    );

    final rotation = await rotateVaultKey(
      oldKey: oldKey,
      vaultId: teamId,
      keyVersion: 1,
      name: 'Team',
      members: members,
      entries: [live],
      trash: trash,
    );
    await alice.api.rotateVault(teamId, rotation.body);
    // A second rotation from the old state comes too late.
    await expectLater(
      alice.api.rotateVault(teamId, await body()),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'key_changed')),
    );

    state = await alice.sync(state.cursor);
    team = state.vaults.singleWhere((v) => v.id == teamId);
    expect(team.rotationPending, isFalse);
    expect(team.keyVersion, 2);
    expect(state.resetVaults, contains(teamId));

    // Carol loads the vault anew and opens it with the new key.
    final carolNow = await carol.sync(carolBefore.cursor);
    expect(carolNow.resetVaults, contains(teamId));
    expect(carol.vaultKeys[teamId], rotation.key);
    final entry = carolNow.entries.singleWhere((e) => e.id == live.id);
    expect(
      (await UnlockedKeys.decryptEntry(
        rotation.key,
        teamId,
        live.id,
        entry.data,
      )).issuer,
      'GitHub',
    );
    // The recycle bin moved along.
    final restored = await alice.api.restoreEntry(binnedId);
    expect(
      (await UnlockedKeys.decryptEntry(
        rotation.key,
        teamId,
        binnedId,
        restored.data,
      )).issuer,
      'GitHub',
    );
    // A write with the old key version is refused.
    await expectLater(
      carol.api.putEntry(
        id: VaultCrypto.newId(),
        vaultId: teamId,
        data: await UnlockedKeys.encryptEntry(oldKey, teamId, 'x', github),
        baseRevision: 0,
        keyVersion: 1,
      ),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'key_changed')),
    );
  });

  test('a deleted account leaves rotations behind', () async {
    final alice = await TestUser.register(h, 'alice');
    final invite = await alice.api.adminCreateInvite();
    final bob = await TestUser.register(h, 'bob', invite: invite.code);
    await alice.sync();
    final teamId = VaultCrypto.newId();
    final key = VaultCrypto.randomBytes(32);
    await alice.api.createVault(
      id: teamId,
      encryptedName: await UnlockedKeys.encryptVaultName(key, teamId, 'T'),
      sealedKey: await VaultCrypto.seal(key, alice.keys.publicKey),
    );
    await alice.api.addMember(
      teamId,
      userId: bob.account.id,
      sealedKey: await VaultCrypto.seal(key, bob.account.publicKey),
      role: VaultRole.read,
    );
    await alice.api.adminDeleteUser(bob.account.id);
    final state = await alice.sync();
    expect(
      state.vaults.singleWhere((v) => v.id == teamId).rotationPending,
      isTrue,
    );
  });
}
