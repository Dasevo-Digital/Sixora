import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:pointycastle/export.dart' as pc;
import 'package:sixora_core/sixora_core.dart';
import 'package:test/test.dart';

/// Just enough CBOR to read what the authenticator writes.
class _Cbor {
  _Cbor(this.bytes);
  final List<int> bytes;
  int at = 0;

  int _length(int info) {
    if (info < 24) return info;
    final size = 1 << (info - 24);
    var value = 0;
    for (var i = 0; i < size; i++) {
      value = value << 8 | bytes[at++];
    }
    return value;
  }

  Object? read() {
    final head = bytes[at++];
    final type = head >> 5;
    final n = _length(head & 31);
    switch (type) {
      case 0:
        return n;
      case 1:
        return -1 - n;
      case 2:
        final out = bytes.sublist(at, at + n);
        at += n;
        return out;
      case 3:
        final out = utf8.decode(bytes.sublist(at, at + n));
        at += n;
        return out;
      case 5:
        return {for (var i = 0; i < n; i++) read(): read()};
    }
    throw StateError('type $type');
  }
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

List<int> _unhex(String s) => [
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
];

/// Verifies with the library directly, without the code under test.
bool _verify(List<int> xy, List<int> message, List<int> der) {
  final curve = pc.ECCurve_secp256r1();
  final point = curve.curve.createPoint(
    BigInt.parse(_hex(xy.sublist(0, 32)), radix: 16),
    BigInt.parse(_hex(xy.sublist(32)), radix: 16),
  );
  // SEQUENCE { INTEGER r, INTEGER s }
  var i = 2;
  BigInt integer() {
    expect(der[i++], 2);
    final n = der[i++];
    final v = BigInt.parse(_hex(der.sublist(i, i + n)), radix: 16);
    i += n;
    return v;
  }

  final r = integer();
  final s = integer();
  final verifier = pc.ECDSASigner(pc.SHA256Digest())
    ..init(
      false,
      pc.PublicKeyParameter<pc.ECPublicKey>(pc.ECPublicKey(point, curve)),
    );
  return verifier.verifySignature(
    Uint8List.fromList(message),
    pc.ECSignature(r, s),
  );
}

void main() {
  PasskeyEntry passkey() => WebAuthn.create(
    rpId: 'example.org',
    rpName: 'Example',
    userHandle: Base64Url.encode([1, 2, 3]),
    userName: 'alice@example.org',
    displayName: 'Alice',
  );

  test('RFC 6979: known signature and public key for P-256', () {
    final key = _unhex(
      'c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721',
    );
    expect(
      _hex(WebAuthn.publicKeyOf(key)),
      '60fed4ba255a9d31c961eb74c6356d68c049b8923b61fa6ce669622e60f29fb6'
      '7903fe1008b8bc99a41ae9e95628bc64f2f1b20c2d7e9f5177a3c294d4462299',
    );
    final der = WebAuthn.sign(key, ascii.encode('sample'));
    expect(
      _hex(der),
      '3046'
      '022100efd48b2aacb6a8fd1140dd9cd45e81d69d2c877b56aaf991c34d0ea84eaf3716'
      '022100f7cb1c942d657c41d436c7a1b6e29f65f3e900dbb9aff4064dc4ab2f843acda8',
    );
  });

  test('a new passkey attests with the right structure', () {
    final p = passkey();
    final a = WebAuthn.attest(p, userVerified: true);
    final object = _Cbor(a.attestationObject).read()! as Map;
    expect(object['fmt'], 'none');
    expect(object['attStmt'], isEmpty);
    final data = object['authData']! as List<int>;
    expect(data, a.authenticatorData);
    expect(
      data.sublist(0, 32),
      c.sha256.convert(utf8.encode('example.org')).bytes,
    );
    // user present, verified, backup eligible, backed up, attested data
    expect(data[32], 0x01 | 0x04 | 0x08 | 0x10 | 0x40);
    expect(data.sublist(33, 37), [0, 0, 0, 0]);
    expect(data.sublist(37, 53), WebAuthn.aaguid);
    final idLength = data[53] << 8 | data[54];
    expect(idLength, 32);
    expect(data.sublist(55, 55 + idLength), Base64Url.decode(p.credentialId));
    final reader = _Cbor(data)..at = 55 + idLength;
    final cose = reader.read()! as Map;
    expect(reader.at, data.length);
    expect(cose[1], 2);
    expect(cose[3], -7);
    expect(cose[-1], 1);
    final xy = WebAuthn.publicKeyOf(Base64Url.decode(p.privateKey));
    expect([...(cose[-2]! as List<int>), ...(cose[-3]! as List<int>)], xy);
    expect(a.publicKey.sublist(a.publicKey.length - 65), [4, ...xy]);
  });

  test('assertions verify and carry the user verification flag', () {
    final p = passkey();
    final client = WebAuthn.clientData(
      type: 'webauthn.get',
      challenge: 'abc',
      origin: 'https://example.org',
    );
    final hash = c.sha256.convert(client).bytes;
    for (final verified in [true, false]) {
      final a = WebAuthn.assertion(p, hash, userVerified: verified);
      expect(a.authenticatorData, hasLength(37));
      expect(a.authenticatorData[32] & 0x04, verified ? 4 : 0);
      expect(a.authenticatorData[32] & 0x01, 1);
      expect(
        _verify(WebAuthn.publicKeyOf(Base64Url.decode(p.privateKey)), [
          ...a.authenticatorData,
          ...hash,
        ], a.signature),
        isTrue,
      );
    }
    expect(jsonDecode(utf8.decode(client))['type'], 'webauthn.get');
  });

  test('rp ids: own domain and parents, nothing else', () {
    expect(WebAuthn.rpIdFits('example.org', 'example.org'), isTrue);
    expect(WebAuthn.rpIdFits('example.org', 'login.example.org'), isTrue);
    expect(WebAuthn.rpIdFits('localhost', 'localhost'), isTrue);
    expect(WebAuthn.rpIdFits('login.example.org', 'example.org'), isFalse);
    expect(WebAuthn.rpIdFits('example.org', 'badexample.org'), isFalse);
    expect(WebAuthn.rpIdFits('example.org', 'example.org.evil.net'), isFalse);
    expect(WebAuthn.rpIdFits('org', 'example.org'), isFalse);
    expect(WebAuthn.rpIdFits('127.0.0.1', '127.0.0.1'), isFalse);
    expect(WebAuthn.rpIdFits('', 'example.org'), isFalse);
    expect(WebAuthn.rpIdFits('.example.org', 'a.example.org'), isFalse);
  });

  test('in a vault entry it is apart from accounts', () async {
    final key = VaultCrypto.randomBytes(32);
    final p = passkey();
    final data = await UnlockedKeys.encryptPasskey(key, 'v', 'e', p);
    final record = await UnlockedKeys.decryptRecord(key, 'v', 'e', data);
    final back = (record as PasskeyRecord).passkey;
    expect(back.toJson(), p.toJson());

    // An older app reads entries with decryptEntry: it must fail cleanly
    // (counted as unreadable), not produce an account without a key.
    await expectLater(
      UnlockedKeys.decryptEntry(key, 'v', 'e', data),
      throwsA(isA<TypeError>()),
    );

    const otp = OtpEntry(issuer: 'A', account: 'b', secret: 'JBSWY3DPEHPK3PXP');
    final otpData = await UnlockedKeys.encryptEntry(key, 'v', 'o', otp);
    expect(
      await UnlockedKeys.decryptRecord(key, 'v', 'o', otpData),
      isA<OtpRecord>(),
    );
    // Bound to its place like every entry.
    await expectLater(
      UnlockedKeys.decryptRecord(key, 'v', 'other', data),
      throwsA(isA<CryptoException>()),
    );
  });

  test('backups carry passkeys and stay readable without them', () async {
    const kdf = KdfParams(memoryKiB: 19456, iterations: 2);
    const otp = OtpEntry(issuer: 'A', account: 'b', secret: 'JBSWY3DPEHPK3PXP');
    final p = passkey();
    final file = await SixoraBackup.encrypt(
      [otp],
      'pw',
      kdf: kdf,
      passkeys: [p],
    );
    final read = await Importers.read(file, password: 'pw');
    expect(read.entries.single.issuer, 'A');
    expect(read.passkeys.single.toJson(), p.toJson());

    final without = await SixoraBackup.encrypt([otp], 'pw', kdf: kdf);
    expect((await Importers.read(without, password: 'pw')).passkeys, isEmpty);
  });

  group('requests from Android', () {
    final hashOrigin =
        '${PasskeyRequest.appOriginPrefix}${Base64Url.encode(List.filled(32, 7))}';
    const options = '''{
      "rp": {"id": "example.com", "name": "Example"},
      "user": {"id": "dXNlcg", "name": "alice", "displayName": "Alice"},
      "challenge": "Y2hhbGxlbmdl",
      "pubKeyCredParams": [{"type": "public-key", "alg": -7}],
      "excludeCredentials": [{"type": "public-key", "id": "b2xk"}],
      "authenticatorSelection": {"userVerification": "required"}
    }''';
    const sign = '''{
      "rpId": "example.com",
      "challenge": "Y2hhbGxlbmdl",
      "allowCredentials": [{"type": "public-key", "id": "YWJj"}],
      "userVerification": "discouraged"
    }''';

    test('reads the options WebAuthn defines', () {
      final r = PasskeyRequest.fromWebAuthn(
        'https://www.example.com',
        options,
        create: true,
      );
      expect(r.rpId, 'example.com');
      expect(r.rpName, 'Example');
      expect(r.userHandle, 'dXNlcg');
      expect(r.algorithms, [-7]);
      expect(r.exclude, ['b2xk']);
      expect(r.userVerification, 'required');
      expect(r.problem, isNull);
      final g = PasskeyRequest.fromWebAuthn(
        'https://example.com',
        sign,
        create: false,
      );
      expect(g.allow, ['YWJj']);
      expect(g.userVerification, 'discouraged');
    });

    test('a browser site must fit its address, an app has none', () {
      expect(
        PasskeyRequest.fromWebAuthn(
          'https://evil.test',
          sign,
          create: false,
        ).problem,
        'SecurityError',
      );
      final app = PasskeyRequest.fromWebAuthn(
        hashOrigin,
        sign,
        create: false,
        androidPackage: 'com.example.app',
      );
      expect(app.fromApp, isTrue);
      expect(app.problem, isNull);
      expect(app.host, 'example.com');
    });

    test('an app gets its own client data, with its identity', () {
      final p = passkey();
      final r = PasskeyRequest.fromWebAuthn(
        hashOrigin,
        sign,
        create: false,
        androidPackage: 'com.example.app',
      );
      final json = passkeyAuthenticationJson(r.signedIn(p, userVerified: true));
      expect(json['rawId'], json['id']);
      final response = json['response']! as Map;
      final data =
          jsonDecode(
                utf8.decode(
                  Base64Url.decode(response['clientDataJSON'] as String),
                ),
              )
              as Map;
      expect(data['type'], 'webauthn.get');
      expect(data['origin'], hashOrigin);
      expect(data['androidPackageName'], 'com.example.app');
    });

    test('a browser that wrote the client data gets that hash signed', () {
      final p = passkey();
      final hash = List<int>.generate(32, (i) => i);
      final r = PasskeyRequest.fromWebAuthn(
        'https://example.com',
        sign,
        create: false,
        clientDataHash: hash,
      );
      final answer = r.signedIn(p, userVerified: false);
      final auth = Base64Url.decode(answer['authenticatorData']! as String);
      final signature = Base64Url.decode(answer['signature']! as String);
      expect(
        _verify(WebAuthn.publicKeyOf(Base64Url.decode(p.privateKey)), [
          ...auth,
          ...hash,
        ], signature),
        isTrue,
      );
    });

    test('a registration answer has what a site reads', () {
      final r = PasskeyRequest.fromWebAuthn(
        'https://example.com',
        options,
        create: true,
      );
      final json = passkeyRegistrationJson(
        r.created(passkey(), userVerified: true),
      );
      final response = json['response']! as Map;
      expect(response['attestationObject'], isA<String>());
      expect(response['publicKeyAlgorithm'], -7);
      expect(json['type'], 'public-key');
    });

    test('asset links name the permission, app and certificate', () {
      const print = 'AA:BB:CC';
      List<Object?> links({
        String relation = 'delegate_permission/common.get_login_creds',
        String package = 'com.example.app',
        String certificate = print,
        String namespace = 'android_app',
      }) => [
        {
          'relation': [relation],
          'target': {
            'namespace': namespace,
            'package_name': package,
            'sha256_cert_fingerprints': [certificate],
          },
        },
      ];
      bool allows(Object? statements) => assetLinksAllow(
        statements,
        package: 'com.example.app',
        fingerprint: print,
      );
      expect(allows(links()), isTrue);
      expect(allows(links(certificate: 'aa:bb:cc')), isTrue);
      expect(allows(links(certificate: 'AA:BB:CD')), isFalse);
      expect(allows(links(package: 'com.other')), isFalse);
      expect(allows(links(namespace: 'web')), isFalse);
      expect(
        allows(links(relation: 'delegate_permission/common.handle_all_urls')),
        isFalse,
      );
      expect(allows({'not': 'a list'}), isFalse);
    });

    test('the site hash matches the one the Android service computes', () {
      expect(
        passkeySiteHash('salz', 'example.com'),
        'EGO7tFHYWdc03T+H6Fh0uqZBiNSyvfRW+QBRUZfTPAc=',
      );
    });
  });
}
