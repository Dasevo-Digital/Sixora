import 'dart:convert';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:sixora_core/sixora_core.dart';
import 'package:test/test.dart';

const _fastKdf = KdfParams(memoryKiB: 19456, iterations: 2);

void main() {
  test('Argon2id agrees with an independent implementation', () async {
    final salt = utf8.encode('somesalt12345678');
    const params = KdfParams(memoryKiB: 19456, iterations: 2);
    final keys = VaultCrypto.derivePasswordKeys(
      'password',
      base64.encode(salt),
      params,
    );
    final reference =
        await crypto.Argon2id(
          parallelism: 1,
          memory: params.memoryKiB,
          iterations: params.iterations,
          hashLength: 32,
        ).deriveKey(
          secretKey: crypto.SecretKey(utf8.encode('password')),
          nonce: salt,
        );
    final master = await reference.extractBytes();
    expect(keys.authKey, VaultCrypto.hkdf(master, info: 'sixora-auth-v1'));
    expect(keys.kek, VaultCrypto.hkdf(master, info: 'sixora-kek-v1'));
    expect(keys.authKey, isNot(keys.kek));
  });

  test('HKDF matches RFC 5869 test case 3', () {
    final ikm = List.filled(22, 0x0b);
    final okm = VaultCrypto.hkdf(ikm, info: '', length: 42);
    expect(
      okm.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      '8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d'
      '9d201395faa4b61a96c8',
    );
  });

  test('encrypt binds to key and aad', () async {
    final key = VaultCrypto.randomBytes(32);
    final box = await VaultCrypto.encryptString(key, 'geheim', aad: 'a');
    expect(await VaultCrypto.decryptString(key, box, aad: 'a'), 'geheim');
    expect(
      () => VaultCrypto.decryptString(key, box, aad: 'b'),
      throwsA(isA<CryptoException>()),
    );
    expect(
      () =>
          VaultCrypto.decryptString(VaultCrypto.randomBytes(32), box, aad: 'a'),
      throwsA(isA<CryptoException>()),
    );
    final tampered = base64.decode(box)..[30] ^= 1;
    expect(
      () => VaultCrypto.decryptString(key, base64.encode(tampered), aad: 'a'),
      throwsA(isA<CryptoException>()),
    );
  });

  test('sealed boxes open only with the right private key', () async {
    final alice = await VaultCrypto.newKeyPair();
    final bob = await VaultCrypto.newKeyPair();
    final sealed = await VaultCrypto.seal([1, 2, 3], alice.publicKey);
    expect(
      await VaultCrypto.unseal(sealed, alice.privateKey, alice.publicKey),
      [1, 2, 3],
    );
    expect(
      () => VaultCrypto.unseal(sealed, bob.privateKey, bob.publicKey),
      throwsA(isA<CryptoException>()),
    );
    expect(VaultCrypto.fingerprint(alice.publicKey), hasLength(24));
  });

  test('recovery keys format and parse', () {
    final key = VaultCrypto.newRecoveryKey();
    expect(VaultCrypto.parseRecoveryKey(key.toLowerCase()), hasLength(32));
    expect(
      VaultCrypto.recoveryKeys(key).auth,
      VaultCrypto.recoveryKeys(key.replaceAll('-', ' ')).auth,
    );
    expect(
      () => VaultCrypto.parseRecoveryKey('ABCD'),
      throwsA(isA<CryptoException>()),
    );
  });

  test('kdf params from a server are bounded', () {
    expect(
      () => KdfParams.fromJson({'alg': 'argon2id', 'm': 1024, 't': 1, 'p': 1}),
      throwsA(isA<CryptoException>()),
    );
    expect(KdfParams.fromJson(KdfParams.recommended.toJson()).memoryKiB, 65536);
  });

  test('new account unlocks with password and recovery key', () async {
    final account = await NewAccount.create(
      username: 'alice',
      password: 'correct horse',
      kdf: _fastKdf,
    );
    final b = account.body;
    final bundle = AccountBundle(
      id: b['userId'] as String,
      username: 'alice',
      isAdmin: false,
      kdf: (b['kdf'] as Map).cast(),
      salt: b['salt'] as String,
      wrappedUserKey: b['wrappedUserKey'] as String,
      publicKey: b['publicKey'] as String,
      encryptedPrivateKey: b['encryptedPrivateKey'] as String,
    );
    final keys = VaultCrypto.derivePasswordKeys(
      'correct horse',
      bundle.salt,
      _fastKdf,
    );
    expect(keys.authKeyB64, account.authKey);
    final unlocked = await UnlockedKeys.unlock(bundle, keys.kek);

    final wrong = VaultCrypto.derivePasswordKeys(
      'wrong',
      bundle.salt,
      _fastKdf,
    );
    expect(
      () => UnlockedKeys.unlock(bundle, wrong.kek),
      throwsA(isA<CryptoException>()),
    );

    final recovery = VaultCrypto.recoveryKeys(account.recoveryKey);
    expect(recovery.auth, b['recoveryAuth']);
    final viaRecovery = await VaultCrypto.decrypt(
      recovery.kek,
      b['recoveryWrappedUserKey'] as String,
      aad: 'sixora-user-key|${bundle.id}',
    );
    expect(viaRecovery, unlocked.userKey);

    final vault = (b['personalVault'] as Map).cast<String, Object?>();
    final vaultDto = VaultDto(
      id: vault['id'] as String,
      personal: true,
      ownerId: bundle.id,
      ownerName: 'alice',
      role: VaultRole.owner,
      encryptedName: vault['encryptedName'] as String,
      sealedKey: vault['sealedKey'] as String,
      memberCount: 1,
    );
    final vaultKey = await unlocked.openVaultKey(vaultDto);
    expect(
      await UnlockedKeys.decryptVaultName(
        vaultKey,
        vaultDto.id,
        vaultDto.encryptedName,
      ),
      'Persönlich',
    );
    const entry = OtpEntry(
      issuer: 'X',
      account: 'y',
      secret: 'JBSWY3DPEHPK3PXP',
    );
    final data = await UnlockedKeys.encryptEntry(
      vaultKey,
      vaultDto.id,
      'e1',
      entry,
    );
    expect(
      (await UnlockedKeys.decryptEntry(
        vaultKey,
        vaultDto.id,
        'e1',
        data,
      )).toJson(),
      entry.toJson(),
    );
    // Bound to its id: the server cannot pass it off as another entry.
    expect(
      () => UnlockedKeys.decryptEntry(vaultKey, vaultDto.id, 'e2', data),
      throwsA(isA<CryptoException>()),
    );
  });

  group('import', () {
    test('sixora backup round trip', () async {
      const entries = [
        OtpEntry(
          issuer: 'A',
          account: 'a',
          secret: 'JBSWY3DPEHPK3PXP',
          group: 'Arbeit',
        ),
      ];
      final file = await SixoraBackup.encrypt(entries, 'pw', kdf: _fastKdf);
      await expectLater(
        Importers.read(file),
        throwsA(isA<NeedsPasswordException>()),
      );
      await expectLater(
        Importers.read(file, password: 'falsch'),
        throwsA(isA<CryptoException>()),
      );
      final r = await Importers.read(file, password: 'pw');
      expect(r.entries.single.toJson(), entries.single.toJson());
    });

    test('aegis plain export', () async {
      final r = await Importers.read(
        jsonEncode({
          'version': 1,
          'header': {'slots': null, 'params': null},
          'db': {
            'version': 3,
            'entries': [
              {
                'type': 'totp',
                'uuid': '1',
                'name': 'me@example.org',
                'issuer': 'Mastodon',
                'favorite': true,
                'groups': ['g1'],
                'info': {
                  'secret': 'JBSWY3DPEHPK3PXP',
                  'algo': 'SHA1',
                  'digits': 6,
                  'period': 30,
                },
              },
              {'type': 'motp', 'name': 'x', 'info': {}},
            ],
            'groups': [
              {'uuid': 'g1', 'name': 'Social'},
            ],
          },
        }),
      );
      expect(r.source, 'Aegis');
      expect(r.entries.single.issuer, 'Mastodon');
      expect(r.entries.single.group, 'Social');
      expect(r.entries.single.favorite, true);
      expect(r.skipped, 1);
    });

    test('2fauth export', () async {
      final r = await Importers.read(
        jsonEncode({
          'app': '2fauth_v5.6.0',
          'count': 1,
          'data': [
            {
              'otp_type': 'totp',
              'account': 'bob',
              'service': 'Example',
              'secret': 'JBSWY3DPEHPK3PXP',
              'digits': 6,
              'algorithm': 'sha1',
              'period': 30,
              'counter': null,
            },
          ],
        }),
      );
      expect(r.source, '2FAuth');
      expect(r.entries.single.account, 'bob');
    });

    test('text with otpauth links', () async {
      final r = await Importers.read(
        'foo\notpauth://totp/A:b?secret=JBSWY3DPEHPK3PXP\n'
        '{"uri":"otpauth://totp/C:d?secret=JBSWY3DPEHPK3PXP&issuer=C"}\n'
        'otpauth://totp/bad?secret=1\n',
      );
      expect(r.entries.map((e) => e.issuer), ['A', 'C']);
      expect(r.skipped, 1);
    });
  });

  group('key rotation and automatic backups', () {
    test('a rotated vault opens only with the new key', () async {
      const vaultId = 'v1';
      final old = VaultCrypto.randomBytes(32);
      final alice = await VaultCrypto.newKeyPair();
      final bob = await VaultCrypto.newKeyPair();
      const entry = OtpEntry(
        issuer: 'A',
        account: 'x',
        secret: 'JBSWY3DPEHPK3PXP',
      );
      final live = EntryDto(
        id: 'e1',
        vaultId: vaultId,
        revision: 3,
        deleted: false,
        data: await UnlockedKeys.encryptEntry(old, vaultId, 'e1', entry),
      );
      final binned = EntryDto(
        id: 'e2',
        vaultId: vaultId,
        revision: 5,
        deleted: true,
        data: await UnlockedKeys.encryptEntry(old, vaultId, 'e2', entry),
      );
      final r = await rotateVaultKey(
        oldKey: old,
        vaultId: vaultId,
        keyVersion: 1,
        name: 'Familie',
        members: [
          MemberDto(
            userId: 'alice',
            username: 'alice',
            role: VaultRole.owner,
            publicKey: alice.publicKey,
          ),
        ],
        entries: [live],
        trash: [binned],
      );
      expect(r.key, isNot(old));
      final members = r.body['members']! as List;
      expect(members, hasLength(1));
      final sealed = (members.single as Map)['sealedKey'] as String;
      expect(
        await VaultCrypto.unseal(sealed, alice.privateKey, alice.publicKey),
        r.key,
      );
      // Bob was not in the list: his key does not open it.
      await expectLater(
        VaultCrypto.unseal(sealed, bob.privateKey, bob.publicKey),
        throwsA(isA<CryptoException>()),
      );
      for (final (list, id, rev) in [
        ('entries', 'e1', 3),
        ('trash', 'e2', 5),
      ]) {
        final e = (r.body[list]! as List).single as Map;
        expect(e['id'], id);
        expect(e['revision'], rev);
        final data = e['data'] as String;
        expect(
          (await UnlockedKeys.decryptEntry(r.key, vaultId, id, data)).issuer,
          'A',
        );
        await expectLater(
          UnlockedKeys.decryptEntry(old, vaultId, id, data),
          throwsA(isA<CryptoException>()),
        );
      }
      expect(
        await UnlockedKeys.decryptVaultName(
          r.key,
          vaultId,
          r.body['encryptedName']! as String,
        ),
        'Familie',
      );
    });

    test('a stored backup key writes files the password opens', () async {
      final key = await BackupKey.derive('pw', kdf: _fastKdf);
      const entries = [
        OtpEntry(issuer: 'A', account: 'x', secret: 'JBSWY3DPEHPK3PXP'),
      ];
      final file = await SixoraBackup.encryptWithKey(entries, key);
      final r = await Importers.read(file, password: 'pw');
      expect(r.entries.single.issuer, 'A');
      expect((await SixoraBackup.decryptWithKey(file, key)).single.issuer, 'A');
      final other = await BackupKey.derive('pw', kdf: _fastKdf);
      await expectLater(
        SixoraBackup.decryptWithKey(file, other),
        throwsA(isA<CryptoException>()),
      );
    });
  });

  test(
    'trusted keys open only with the same account key and account',
    () async {
      final userKey = VaultCrypto.randomBytes(32);
      final data = await TrustedKeys.encrypt(userKey, 'acc1', {'bob': 'KEY'});
      expect(await TrustedKeys.decrypt(userKey, 'acc1', data), {'bob': 'KEY'});
      expect(await TrustedKeys.decrypt(userKey, 'acc1', ''), isEmpty);
      await expectLater(
        TrustedKeys.decrypt(userKey, 'acc2', data),
        throwsA(isA<CryptoException>()),
      );
      await expectLater(
        TrustedKeys.decrypt(VaultCrypto.randomBytes(32), 'acc1', data),
        throwsA(isA<CryptoException>()),
      );
    },
  );
}
