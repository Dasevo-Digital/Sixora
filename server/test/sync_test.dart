import 'dart:io';

import 'package:shelf/shelf_io.dart' as io;
import 'package:sixora_core/sixora_core.dart';
import 'package:sixora_server/sixora_server.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Entries, sync, recycle bin and the long poll.
void main() {
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.start();
  });
  tearDown(() => h.stop());

  test('entries sync with revisions, conflicts and tombstones', () async {
    final alice = await TestUser.register(h, 'alice');
    final first = await alice.sync();
    expect(first.vaults.single.personal, isTrue);
    final vaultId = alice.personalVaultId;

    final id = VaultCrypto.newId();
    final created = await alice.put(vaultId, id, github);
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
      github.copyWith(account: 'alice2'),
      base: 1,
    );
    expect(updated.revision, 2);
    // A second device still on revision 1 gets a conflict.
    await expectLater(
      alice.put(vaultId, id, github, base: 1),
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

  test('deleted entries can be restored or purged', () async {
    final alice = await TestUser.register(h, 'alice');
    final first = await alice.sync();
    final vaultId = alice.personalVaultId;
    final id = VaultCrypto.newId();
    await alice.put(vaultId, id, github);
    final deleted = await alice.api.deleteEntry(id, baseRevision: 1);
    // The normal sync only sees the tombstone, without ciphertext.
    final after = await alice.sync(first.cursor);
    expect(after.entries.single.deleted, isTrue);
    expect(after.entries.single.data, isEmpty);

    final trash = await alice.api.trash();
    expect(trash.single.id, id);
    expect(trash.single.deletedAt, isNotNull);
    expect(
      (await UnlockedKeys.decryptEntry(
        alice.vaultKeys[vaultId]! as dynamic,
        vaultId,
        id,
        trash.single.data,
      )).issuer,
      'GitHub',
    );

    final restored = await alice.api.restoreEntry(id);
    expect(restored.deleted, isFalse);
    expect(restored.revision, deleted.revision + 1);
    final synced = await alice.sync(after.cursor);
    expect(synced.entries.single.deleted, isFalse);
    expect(await alice.api.trash(), isEmpty);

    await alice.api.deleteEntry(id, baseRevision: restored.revision);
    await alice.api.purgeEntry(id);
    expect(await alice.api.trash(), isEmpty);
    await expectLater(
      alice.api.restoreEntry(id),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
    );
  });

  test('other users see nothing of my recycle bin', () async {
    final alice = await TestUser.register(h, 'alice');
    final invite = await alice.api.adminCreateInvite();
    final bob = await TestUser.register(h, 'bob', invite: invite.code);
    await alice.sync();
    final id = VaultCrypto.newId();
    await alice.put(alice.personalVaultId, id, github);
    await alice.api.deleteEntry(id, baseRevision: 1);
    expect(await bob.api.trash(), isEmpty);
    await expectLater(
      bob.api.restoreEntry(id),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
    );
    await expectLater(
      bob.api.purgeEntry(id),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
    );
  });

  test('the recycle bin forgets after 30 days', () async {
    var now = DateTime.utc(2026, 1, 1);
    await h.stop();
    final db = openSixoraDatabase(':memory:');
    h = Harness();
    h.app = SixoraServerApp(
      db: db,
      registration: Registration.open,
      clock: () => now,
    );
    h.server = await io.serve(h.app.handler, InternetAddress.loopbackIPv4, 0);
    h.url = Uri.parse('http://127.0.0.1:${h.server.port}/');
    final alice = await TestUser.register(h, 'alice');
    await alice.sync();
    final id = VaultCrypto.newId();
    await alice.put(alice.personalVaultId, id, github);
    await alice.api.deleteEntry(id, baseRevision: 1);
    now = now.add(const Duration(days: 29));
    h.app.maintain();
    expect(await alice.api.trash(), hasLength(1));
    now = now.add(const Duration(days: 2));
    h.app.maintain();
    expect(await alice.api.trash(), isEmpty);
  });

  test('a waiting sync returns as soon as something changes', () async {
    final alice = await TestUser.register(h, 'alice');
    final first = await alice.sync();
    // Nothing changes: the request waits out its time.
    final quiet = Stopwatch()..start();
    final idle = await alice.api.sync(
      first.cursor,
      wait: const Duration(seconds: 1),
    );
    expect(quiet.elapsedMilliseconds, greaterThanOrEqualTo(900));
    expect(idle.entries, isEmpty);

    // Another device writes: the waiting request answers right away.
    final watch = Stopwatch()..start();
    final waiting = h.api()..token = alice.api.token;
    final pending = waiting.sync(
      first.cursor,
      wait: const Duration(seconds: 20),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await alice.put(alice.personalVaultId, VaultCrypto.newId(), github);
    final woke = await pending;
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    expect(woke.entries, hasLength(1));
  });
}
