import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:cryptography/cryptography.dart';
import 'package:hashlib/hashlib.dart' as h;

import '../otp/base32.dart';

/// Thrown when decryption fails: wrong password or key, or tampered data.
class CryptoException implements Exception {
  const CryptoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Argon2id parameters, stored on the server next to the salt so that every
/// client derives the same key.
class KdfParams {
  const KdfParams({
    this.memoryKiB = 65536,
    this.iterations = 3,
    this.parallelism = 1,
  });

  /// Default for new accounts: 64 MiB, 3 passes (OWASP recommendation is at
  /// least 19 MiB / 2 passes).
  static const recommended = KdfParams();

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  Map<String, Object?> toJson() => {
    'alg': 'argon2id',
    'm': memoryKiB,
    't': iterations,
    'p': parallelism,
  };

  /// Rejects parameters that are too weak or would exhaust a phone's
  /// memory, so a malicious server cannot weaken or stall the clients.
  factory KdfParams.fromJson(Map<String, Object?> json) {
    final params = KdfParams(
      memoryKiB: (json['m'] as num?)?.toInt() ?? 0,
      iterations: (json['t'] as num?)?.toInt() ?? 0,
      parallelism: (json['p'] as num?)?.toInt() ?? 0,
    );
    if (json['alg'] != 'argon2id' ||
        params.memoryKiB < 19456 ||
        params.memoryKiB > 1048576 ||
        params.iterations < 2 ||
        params.iterations > 20 ||
        params.parallelism < 1 ||
        params.parallelism > 8) {
      throw const CryptoException('Unzulässige Schlüsselparameter');
    }
    return params;
  }
}

/// The two keys derived from the master password. [authKey] is sent to the
/// server as login proof; [kek] never leaves the device and unwraps the
/// user key.
class PasswordKeys {
  PasswordKeys._(this.authKey, this.kek);
  final Uint8List authKey;
  final Uint8List kek;

  String get authKeyB64 => base64.encode(authKey);
}

/// Cryptographic building blocks of the Sixora vault.
///
/// Key hierarchy:
/// * master password --Argon2id--> master key --HKDF--> auth key + KEK
/// * KEK (and the recovery key) wrap the random **user key**
/// * the user key encrypts the user's X25519 private key
/// * each vault has a random **vault key**, sealed to the public key of
///   every member
/// * the vault key encrypts entries and the vault name
abstract final class VaultCrypto {
  static final _random = Random.secure();
  static final _aead = Xchacha20.poly1305Aead();
  static final _x25519 = X25519();
  static const _version = 1;

  static Uint8List randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

  static String newSaltB64() => base64.encode(randomBytes(16));

  /// RFC 4122 version 4 UUID.
  static String newId() {
    final b = randomBytes(16);
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Slow on purpose (about 0.2–2 s). Call it outside the UI isolate.
  static PasswordKeys derivePasswordKeys(
    String password,
    String saltB64,
    KdfParams params,
  ) {
    final master = h.Argon2(
      type: h.Argon2Type.argon2id,
      version: h.Argon2Version.v13,
      memorySizeKB: params.memoryKiB,
      iterations: params.iterations,
      parallelism: params.parallelism,
      hashLength: 32,
      salt: base64.decode(saltB64),
    ).convert(utf8.encode(password)).bytes;
    return PasswordKeys._(
      hkdf(master, info: 'sixora-auth-v1'),
      hkdf(master, info: 'sixora-kek-v1'),
    );
  }

  /// HKDF-SHA256 (RFC 5869).
  static Uint8List hkdf(
    List<int> ikm, {
    required String info,
    List<int> salt = const [],
    int length = 32,
  }) {
    final prk = c.Hmac(
      c.sha256,
      salt.isEmpty ? List.filled(32, 0) : salt,
    ).convert(ikm).bytes;
    final out = BytesBuilder();
    var previous = <int>[];
    for (var i = 1; out.length < length; i++) {
      previous = c.Hmac(
        c.sha256,
        prk,
      ).convert([...previous, ...utf8.encode(info), i]).bytes;
      out.add(previous);
    }
    return Uint8List.sublistView(out.takeBytes(), 0, length);
  }

  // --- Symmetric encryption ------------------------------------------------

  /// XChaCha20-Poly1305; output is `base64(version | nonce | ct | tag)`.
  /// [aad] binds the ciphertext to its context (e.g. vault and entry id), so
  /// the server cannot swap blobs around unnoticed.
  static Future<String> encrypt(
    List<int> key,
    List<int> plaintext, {
    String aad = '',
  }) async {
    final nonce = randomBytes(24);
    final box = await _aead.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: utf8.encode(aad),
    );
    return base64.encode([
      _version,
      ...nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  static Future<Uint8List> decrypt(
    List<int> key,
    String envelope, {
    String aad = '',
  }) async {
    try {
      final data = base64.decode(envelope);
      if (data.length < 1 + 24 + 16 || data[0] != _version) {
        throw const CryptoException('Unbekanntes Format');
      }
      final box = SecretBox(
        data.sublist(25, data.length - 16),
        nonce: data.sublist(1, 25),
        mac: Mac(data.sublist(data.length - 16)),
      );
      final clear = await _aead.decrypt(
        box,
        secretKey: SecretKey(key),
        aad: utf8.encode(aad),
      );
      return Uint8List.fromList(clear);
    } on CryptoException {
      rethrow;
    } catch (_) {
      throw const CryptoException('Entschlüsselung fehlgeschlagen');
    }
  }

  static Future<String> encryptString(
    List<int> key,
    String text, {
    String aad = '',
  }) => encrypt(key, utf8.encode(text), aad: aad);

  static Future<String> decryptString(
    List<int> key,
    String envelope, {
    String aad = '',
  }) async => utf8.decode(await decrypt(key, envelope, aad: aad));

  // --- Public key encryption -----------------------------------------------

  static Future<({String publicKey, Uint8List privateKey})> newKeyPair() async {
    final pair = await _x25519.newKeyPairFromSeed(randomBytes(32));
    final pub = await pair.extractPublicKey();
    return (
      publicKey: base64.encode(pub.bytes),
      privateKey: Uint8List.fromList(await pair.extractPrivateKeyBytes()),
    );
  }

  /// Anonymous sealed box: only the holder of the private key belonging to
  /// [publicKeyB64] can open it. Format:
  /// `base64(version | ephemeral public key | nonce | ct | tag)`.
  static Future<String> seal(List<int> message, String publicKeyB64) async {
    final recipient = base64.decode(publicKeyB64);
    if (recipient.length != 32) {
      throw const CryptoException('Ungültiger Schlüssel');
    }
    final eph = await _x25519.newKeyPairFromSeed(randomBytes(32));
    final ephPub = (await eph.extractPublicKey()).bytes;
    final shared = await _x25519.sharedSecretKey(
      keyPair: eph,
      remotePublicKey: SimplePublicKey(recipient, type: KeyPairType.x25519),
    );
    final key = hkdf(
      await shared.extractBytes(),
      salt: [...ephPub, ...recipient],
      info: 'sixora-seal-v1',
    );
    final inner = base64.decode(
      await encrypt(key, message, aad: 'sixora-seal'),
    );
    return base64.encode([_version, ...ephPub, ...inner.sublist(1)]);
  }

  static Future<Uint8List> unseal(
    String sealed,
    List<int> privateKey,
    String publicKeyB64,
  ) async {
    try {
      final data = base64.decode(sealed);
      if (data.length < 1 + 32 + 24 + 16 || data[0] != _version) {
        throw const CryptoException('Unbekanntes Format');
      }
      final ephPub = data.sublist(1, 33);
      final pair = await _x25519.newKeyPairFromSeed(privateKey);
      final shared = await _x25519.sharedSecretKey(
        keyPair: pair,
        remotePublicKey: SimplePublicKey(ephPub, type: KeyPairType.x25519),
      );
      final key = hkdf(
        await shared.extractBytes(),
        salt: [...ephPub, ...base64.decode(publicKeyB64)],
        info: 'sixora-seal-v1',
      );
      return decrypt(
        key,
        base64.encode([_version, ...data.sublist(33)]),
        aad: 'sixora-seal',
      );
    } on CryptoException {
      rethrow;
    } catch (_) {
      throw const CryptoException('Entschlüsselung fehlgeschlagen');
    }
  }

  /// Short, human-comparable fingerprint of a public key, e.g. to verify
  /// with a colleague before sharing a vault.
  static String fingerprint(String publicKeyB64) {
    final digest = c.sha256.convert(base64.decode(publicKeyB64)).bytes;
    final hex = digest
        .take(10)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return [
      for (var i = 0; i < hex.length; i += 4) hex.substring(i, i + 4),
    ].join(' ');
  }

  // --- Recovery key --------------------------------------------------------

  /// A new recovery key: 32 random bytes, shown as base32 in groups of four.
  static String newRecoveryKey() => formatRecoveryKey(randomBytes(32));

  static String formatRecoveryKey(List<int> bytes) {
    final s = Base32.encode(bytes);
    return [
      for (var i = 0; i < s.length; i += 4)
        s.substring(i, min(i + 4, s.length)),
    ].join('-');
  }

  static Uint8List parseRecoveryKey(String text) {
    try {
      final bytes = Base32.decode(text);
      if (bytes.length == 32) return bytes;
    } on FormatException {
      // handled below
    }
    throw const CryptoException('Wiederherstellungsschlüssel ist ungültig');
  }

  /// Login proof and wrapping key derived from the recovery key.
  static ({String auth, Uint8List kek}) recoveryKeys(String recoveryKey) {
    final raw = parseRecoveryKey(recoveryKey);
    return (
      auth: base64.encode(hkdf(raw, info: 'sixora-recovery-auth-v1')),
      kek: hkdf(raw, info: 'sixora-recovery-kek-v1'),
    );
  }
}
