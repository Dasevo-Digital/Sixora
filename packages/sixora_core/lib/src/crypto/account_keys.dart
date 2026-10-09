import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import '../api/models.dart';
import '../otp/entry.dart';
import 'vault_crypto.dart';

/// Argon2id in a background isolate, so the UI keeps running.
Future<PasswordKeys> derivePasswordKeysAsync(
  String password,
  String saltB64,
  KdfParams params,
) => Isolate.run(
  () => VaultCrypto.derivePasswordKeys(password, saltB64, params),
);

/// The decrypted key material of a logged-in, unlocked account. Lives only
/// in memory (and, if the user opts in, in the platform's secure storage).
class UnlockedKeys {
  UnlockedKeys({
    required this.userKey,
    required this.privateKey,
    required this.publicKey,
  });

  final Uint8List userKey;
  final Uint8List privateKey;
  final String publicKey;

  /// Unwraps the account with keys derived from the master password.
  static Future<UnlockedKeys> unlock(
    AccountBundle account,
    Uint8List kek,
  ) async {
    final Uint8List userKey;
    try {
      userKey = await VaultCrypto.decrypt(
        kek,
        account.wrappedUserKey,
        aad: 'sixora-user-key|${account.id}',
      );
    } on CryptoException {
      throw const CryptoException('Master-Passwort ist falsch');
    }
    return fromUserKey(account, userKey);
  }

  static Future<UnlockedKeys> fromUserKey(
    AccountBundle account,
    Uint8List userKey,
  ) async {
    final privateKey = await VaultCrypto.decrypt(
      userKey,
      account.encryptedPrivateKey,
      aad: 'sixora-private-key|${account.id}',
    );
    return UnlockedKeys(
      userKey: userKey,
      privateKey: privateKey,
      publicKey: account.publicKey,
    );
  }

  Future<Uint8List> openVaultKey(VaultDto vault) =>
      VaultCrypto.unseal(vault.sealedKey, privateKey, publicKey);

  static String _entryAad(String vaultId, String entryId) =>
      'sixora-entry|$vaultId|$entryId';

  static String _vaultNameAad(String vaultId) => 'sixora-vault-name|$vaultId';

  static Future<String> encryptEntry(
    Uint8List vaultKey,
    String vaultId,
    String entryId,
    OtpEntry entry,
  ) => VaultCrypto.encryptString(
    vaultKey,
    jsonEncode(entry.toJson()),
    aad: _entryAad(vaultId, entryId),
  );

  static Future<OtpEntry> decryptEntry(
    Uint8List vaultKey,
    String vaultId,
    String entryId,
    String data,
  ) async => OtpEntry.fromJson(
    (jsonDecode(
              await VaultCrypto.decryptString(
                vaultKey,
                data,
                aad: _entryAad(vaultId, entryId),
              ),
            )
            as Map)
        .cast(),
  );

  static Future<String> encryptVaultName(
    Uint8List vaultKey,
    String vaultId,
    String name,
  ) => VaultCrypto.encryptString(vaultKey, name, aad: _vaultNameAad(vaultId));

  static Future<String> decryptVaultName(
    Uint8List vaultKey,
    String vaultId,
    String data,
  ) => VaultCrypto.decryptString(vaultKey, data, aad: _vaultNameAad(vaultId));
}

/// A vault under a fresh key, ready for `POST vaults/<id>/rotate`.
///
/// Entries are re-encrypted as they are, without being parsed, so fields a
/// newer app version added survive. A member that is no longer in [members]
/// never learns the new key.
Future<({Map<String, Object?> body, Uint8List key})> rotateVaultKey({
  required Uint8List oldKey,
  required String vaultId,
  required int keyVersion,
  required String name,
  required List<MemberDto> members,
  required List<EntryDto> entries,
  required List<EntryDto> trash,
}) async {
  final key = VaultCrypto.randomBytes(32);
  Future<List<Map<String, Object?>>> reencrypt(List<EntryDto> list) async => [
    for (final e in list)
      {
        'id': e.id,
        'revision': e.revision,
        'data': await VaultCrypto.encryptString(
          key,
          await VaultCrypto.decryptString(
            oldKey,
            e.data,
            aad: UnlockedKeys._entryAad(vaultId, e.id),
          ),
          aad: UnlockedKeys._entryAad(vaultId, e.id),
        ),
      },
  ];
  return (
    key: key,
    body: <String, Object?>{
      'keyVersion': keyVersion,
      'encryptedName': await UnlockedKeys.encryptVaultName(key, vaultId, name),
      'members': [
        for (final m in members)
          {
            'userId': m.userId,
            'sealedKey': await VaultCrypto.seal(key, m.publicKey),
          },
      ],
      'entries': await reencrypt(entries),
      'trash': await reencrypt(trash),
    },
  );
}

/// Everything the client creates when an account is registered.
class NewAccount {
  NewAccount._(this.body, this.recoveryKey, this.authKey, this.kek);

  /// Request body for `POST auth/register` (without device and invite).
  final Map<String, Object?> body;

  /// Shown once to the user; the only way back in without the password.
  final String recoveryKey;
  final String authKey;
  final Uint8List kek;

  /// [userId] and the personal vault id are generated here, because the
  /// ciphertexts are bound to them.
  static Future<NewAccount> create({
    required String username,
    required String password,
    KdfParams kdf = KdfParams.recommended,
    String personalVaultName = 'Persönlich',
  }) async {
    final userId = VaultCrypto.newId();
    final salt = VaultCrypto.newSaltB64();
    final keys = await derivePasswordKeysAsync(password, salt, kdf);
    final userKey = VaultCrypto.randomBytes(32);
    final pair = await VaultCrypto.newKeyPair();
    final recoveryKey = VaultCrypto.newRecoveryKey();
    final recovery = VaultCrypto.recoveryKeys(recoveryKey);
    final vaultId = VaultCrypto.newId();
    final vaultKey = VaultCrypto.randomBytes(32);
    final body = <String, Object?>{
      'userId': userId,
      'username': username,
      'kdf': kdf.toJson(),
      'salt': salt,
      'authKey': keys.authKeyB64,
      'wrappedUserKey': await VaultCrypto.encrypt(
        keys.kek,
        userKey,
        aad: 'sixora-user-key|$userId',
      ),
      'publicKey': pair.publicKey,
      'encryptedPrivateKey': await VaultCrypto.encrypt(
        userKey,
        pair.privateKey,
        aad: 'sixora-private-key|$userId',
      ),
      'recoveryWrappedUserKey': await VaultCrypto.encrypt(
        recovery.kek,
        userKey,
        aad: 'sixora-user-key|$userId',
      ),
      'recoveryAuth': recovery.auth,
      'personalVault': {
        'id': vaultId,
        'encryptedName': await UnlockedKeys.encryptVaultName(
          vaultKey,
          vaultId,
          personalVaultName,
        ),
        'sealedKey': await VaultCrypto.seal(vaultKey, pair.publicKey),
      },
    };
    return NewAccount._(body, recoveryKey, keys.authKeyB64, keys.kek);
  }
}

/// Request body pieces to replace the master password (change or recovery):
/// new salt, new auth key and the user key wrapped with the new KEK.
Future<Map<String, Object?>> rewrapForNewPassword({
  required String userId,
  required Uint8List userKey,
  required String newPassword,
  KdfParams kdf = KdfParams.recommended,
}) async {
  final salt = VaultCrypto.newSaltB64();
  final keys = await derivePasswordKeysAsync(newPassword, salt, kdf);
  return {
    'newKdf': kdf.toJson(),
    'newSalt': salt,
    'newAuthKey': keys.authKeyB64,
    'newWrappedUserKey': await VaultCrypto.encrypt(
      keys.kek,
      userKey,
      aad: 'sixora-user-key|$userId',
    ),
  };
}

/// A fresh recovery key for an unlocked account.
Future<({String recoveryKey, String wrapped, String auth})> newRecoveryFor({
  required String userId,
  required Uint8List userKey,
}) async {
  final recoveryKey = VaultCrypto.newRecoveryKey();
  final r = VaultCrypto.recoveryKeys(recoveryKey);
  return (
    recoveryKey: recoveryKey,
    wrapped: await VaultCrypto.encrypt(
      r.kek,
      userKey,
      aad: 'sixora-user-key|$userId',
    ),
    auth: r.auth,
  );
}
