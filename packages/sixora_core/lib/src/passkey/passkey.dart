import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:pointycastle/api.dart' show PrivateKeyParameter;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256r1.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';

import '../crypto/vault_crypto.dart';

/// A passkey for a website, stored like an OTP account: encrypted with the
/// vault key, synced and shared with the vault. The server never sees it.
class PasskeyEntry {
  const PasskeyEntry({
    required this.rpId,
    required this.rpName,
    required this.userHandle,
    required this.userName,
    required this.displayName,
    required this.credentialId,
    required this.privateKey,
    required this.createdAt,
  });

  /// The website's domain, e.g. `github.com`.
  final String rpId;
  final String rpName;

  /// The website's id for the user (base64url).
  final String userHandle;
  final String userName;
  final String displayName;

  /// base64url.
  final String credentialId;

  /// The P-256 private scalar, 32 bytes (base64url).
  final String privateKey;
  final DateTime createdAt;

  String get label => rpName.isNotEmpty ? rpName : rpId;
  String get account => userName.isNotEmpty ? userName : displayName;

  Map<String, Object?> toJson() => {
    'rpId': rpId,
    'rpName': rpName,
    'userHandle': userHandle,
    'userName': userName,
    'displayName': displayName,
    'credentialId': credentialId,
    'privateKey': privateKey,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory PasskeyEntry.fromJson(Map<String, Object?> j) {
    final rpId = j['rpId'];
    final credentialId = j['credentialId'];
    final privateKey = j['privateKey'];
    if (rpId is! String || credentialId is! String || privateKey is! String) {
      throw const FormatException('Passkey ist unvollständig');
    }
    return PasskeyEntry(
      rpId: rpId,
      rpName: j['rpName'] as String? ?? '',
      userHandle: j['userHandle'] as String? ?? '',
      userName: j['userName'] as String? ?? '',
      displayName: j['displayName'] as String? ?? '',
      credentialId: credentialId,
      privateKey: privateKey,
      createdAt:
          DateTime.tryParse(j['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

/// Base64url without padding, as WebAuthn uses it.
abstract final class Base64Url {
  static String encode(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List decode(String text) =>
      base64Url.decode(base64Url.normalize(text));
}

/// What the authenticator hands back when a passkey is created.
class PasskeyAttestation {
  const PasskeyAttestation({
    required this.authenticatorData,
    required this.attestationObject,
    required this.publicKey,
  });
  final Uint8List authenticatorData;
  final Uint8List attestationObject;

  /// SubjectPublicKeyInfo (DER), for `getPublicKey()`.
  final Uint8List publicKey;
}

/// What the authenticator hands back when a passkey signs in.
class PasskeyAssertion {
  const PasskeyAssertion({
    required this.authenticatorData,
    required this.signature,
  });
  final Uint8List authenticatorData;
  final Uint8List signature;
}

/// The authenticator side of WebAuthn, in plain Dart: makes ES256 passkeys
/// and answers with attestation "none" and assertions.
///
/// The signature counter stays 0, as for every synced passkey: a counter
/// would need a write to the vault on each use.
abstract final class WebAuthn {
  static const algorithmEs256 = -7;

  /// Identifies Sixora as the authenticator to websites.
  static final aaguid = Uint8List.fromList(const [
    0x6f, 0x1d, 0x4a, 0x0e, 0x92, 0x3b, 0x4c, 0x57, //
    0xa8, 0x15, 0x3e, 0x77, 0x0c, 0xd2, 0x91, 0x6b,
  ]);

  static final _curve = ECCurve_secp256r1();

  static const _flagUserPresent = 0x01;
  static const _flagUserVerified = 0x04;
  static const _flagBackupEligible = 0x08;
  static const _flagBackedUp = 0x10;
  static const _flagAttestedData = 0x40;

  /// Whether a page on [host] may use [rpId]: the host itself or a parent
  /// domain of it, never an address or a bare top-level domain. Passkeys
  /// stay bound to exactly their rpId, so a page can only ever reach those
  /// of its own domain and its parents.
  static bool rpIdFits(String rpId, String host) {
    final id = rpId.toLowerCase();
    final origin = host.toLowerCase();
    if (id.isEmpty || id.startsWith('.') || id.endsWith('.')) return false;
    if (id.contains(':') || RegExp(r'^[0-9.]+$').hasMatch(id)) return false;
    if (id != 'localhost' && !id.contains('.')) return false;
    return origin == id || origin.endsWith('.$id');
  }

  /// A new passkey with a fresh key pair and credential id.
  static PasskeyEntry create({
    required String rpId,
    required String rpName,
    required String userHandle,
    required String userName,
    required String displayName,
    DateTime? now,
  }) => PasskeyEntry(
    rpId: rpId,
    rpName: rpName,
    userHandle: userHandle,
    userName: userName,
    displayName: displayName,
    credentialId: Base64Url.encode(VaultCrypto.randomBytes(32)),
    privateKey: Base64Url.encode(_newScalar()),
    createdAt: (now ?? DateTime.now()).toUtc(),
  );

  /// 32 random bytes in the range 1 … n-1; out of range is thrown away.
  static Uint8List _newScalar() {
    while (true) {
      final bytes = VaultCrypto.randomBytes(32);
      final d = _toBigInt(bytes);
      if (d > BigInt.zero && d < _curve.n) return bytes;
    }
  }

  static List<int> hash(List<int> bytes) => c.sha256.convert(bytes).bytes;

  /// `clientDataJSON` for a ceremony; the challenge is base64url.
  static Uint8List clientData({
    required String type,
    required String challenge,
    required String origin,
  }) => utf8.encode(
    jsonEncode({
      'type': type,
      'challenge': challenge,
      'origin': origin,
      'crossOrigin': false,
    }),
  );

  static PasskeyAttestation attest(
    PasskeyEntry passkey, {
    required bool userVerified,
  }) {
    final point = _publicPoint(passkey);
    final x = _fixed(point.x!.toBigInteger()!);
    final y = _fixed(point.y!.toBigInteger()!);
    final credentialId = Base64Url.decode(passkey.credentialId);
    final authData = BytesBuilder(copy: false)
      ..add(_authenticatorHeader(passkey.rpId, userVerified, attested: true))
      ..add(aaguid)
      ..add([credentialId.length >> 8, credentialId.length & 0xff])
      ..add(credentialId)
      ..add(_coseKey(x, y));
    final data = authData.takeBytes();
    return PasskeyAttestation(
      authenticatorData: data,
      attestationObject: _attestationNone(data),
      publicKey: Uint8List.fromList([..._spkiPrefix, 0x04, ...x, ...y]),
    );
  }

  /// Signs in: [clientDataHash] is the SHA-256 of `clientDataJSON`.
  static PasskeyAssertion assertion(
    PasskeyEntry passkey,
    List<int> clientDataHash, {
    required bool userVerified,
  }) {
    final data = _authenticatorHeader(
      passkey.rpId,
      userVerified,
      attested: false,
    );
    return PasskeyAssertion(
      authenticatorData: data,
      signature: sign(Base64Url.decode(passkey.privateKey), [
        ...data,
        ...clientDataHash,
      ]),
    );
  }

  /// ES256 over [message] in DER form, with a deterministic nonce
  /// (RFC 6979), so a weak random source cannot reveal the key.
  static Uint8List sign(List<int> privateKey, List<int> message) {
    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
      ..init(
        true,
        PrivateKeyParameter<ECPrivateKey>(
          ECPrivateKey(_toBigInt(privateKey), _curve),
        ),
      );
    final signature =
        signer.generateSignature(Uint8List.fromList(message)) as ECSignature;
    final r = _derInteger(signature.r);
    final s = _derInteger(signature.s);
    return Uint8List.fromList([0x30, r.length + s.length, ...r, ...s]);
  }

  /// Uncompressed public key (x and y, 32 bytes each).
  static Uint8List publicKeyOf(List<int> privateKey) {
    final point = (_curve.G * _toBigInt(privateKey))!;
    return Uint8List.fromList([
      ..._fixed(point.x!.toBigInteger()!),
      ..._fixed(point.y!.toBigInteger()!),
    ]);
  }

  static ECPoint _publicPoint(PasskeyEntry passkey) =>
      (_curve.G * _toBigInt(Base64Url.decode(passkey.privateKey)))!;

  static Uint8List _authenticatorHeader(
    String rpId,
    bool userVerified, {
    required bool attested,
  }) {
    final flags =
        _flagUserPresent |
        _flagBackupEligible |
        _flagBackedUp |
        (userVerified ? _flagUserVerified : 0) |
        (attested ? _flagAttestedData : 0);
    return Uint8List.fromList([
      ...c.sha256.convert(utf8.encode(rpId)).bytes,
      flags,
      0, 0, 0, 0, // signature counter
    ]);
  }

  /// `{1: 2, 3: -7, -1: 1, -2: x, -3: y}` in CBOR: an EC2 key for ES256.
  static List<int> _coseKey(List<int> x, List<int> y) => [
    0xa5,
    0x01, 0x02, // kty: EC2
    0x03, 0x26, // alg: ES256
    0x20, 0x01, // crv: P-256
    0x21, 0x58, 0x20, ...x,
    0x22, 0x58, 0x20, ...y,
  ];

  /// `{"fmt": "none", "attStmt": {}, "authData": …}` in CBOR.
  static Uint8List _attestationNone(List<int> authData) {
    final length = authData.length;
    return Uint8List.fromList([
      0xa3,
      0x63,
      ...ascii.encode('fmt'),
      0x64,
      ...ascii.encode('none'),
      0x67,
      ...ascii.encode('attStmt'),
      0xa0,
      0x68,
      ...ascii.encode('authData'),
      0x59,
      length >> 8,
      length & 0xff,
      ...authData,
    ]);
  }

  /// SubjectPublicKeyInfo of a P-256 key, up to the point's first byte.
  static const _spkiPrefix = [
    0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, //
    0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
    0x42, 0x00,
  ];

  static BigInt _toBigInt(List<int> bytes) {
    var value = BigInt.zero;
    for (final b in bytes) {
      value = (value << 8) | BigInt.from(b);
    }
    return value;
  }

  static Uint8List _fixed(BigInt value) {
    final bytes = Uint8List(32);
    var rest = value;
    for (var i = 31; i >= 0; i--) {
      bytes[i] = (rest & BigInt.from(0xff)).toInt();
      rest >>= 8;
    }
    return bytes;
  }

  static List<int> _derInteger(BigInt value) {
    var bytes = _fixed(value).skipWhile((b) => b == 0).toList();
    if (bytes.isEmpty || bytes.first >= 0x80) bytes = [0, ...bytes];
    return [0x02, bytes.length, ...bytes];
  }
}
