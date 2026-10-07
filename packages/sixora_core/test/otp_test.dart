import 'dart:convert';

import 'package:sixora_core/sixora_core.dart';
import 'package:test/test.dart';

void main() {
  group('Base32', () {
    test('round trip and lenient decoding', () {
      final bytes = utf8.encode('12345678901234567890');
      final encoded = Base32.encode(bytes);
      expect(encoded, 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
      expect(Base32.decode(encoded.toLowerCase()), bytes);
      expect(Base32.decode('gezd gnbv-gy3t qojq gezd gnbv gy3t qojq=='), bytes);
      expect(() => Base32.decode('ABC1'), throwsFormatException);
    });
  });

  group('HOTP (RFC 4226)', () {
    test('test vectors', () {
      final key = utf8.encode('12345678901234567890');
      const expected = [
        '755224', '287082', '359152', '969429', '338314', //
        '254676', '287922', '162583', '399871', '520489',
      ];
      for (var i = 0; i < expected.length; i++) {
        expect(Otp.hotp(key, i), expected[i]);
      }
    });
  });

  group('TOTP (RFC 6238)', () {
    final keys = {
      OtpAlgorithm.sha1: utf8.encode('12345678901234567890'),
      OtpAlgorithm.sha256: utf8.encode('12345678901234567890123456789012'),
      OtpAlgorithm.sha512: utf8.encode(
        '1234567890123456789012345678901234567890123456789012345678901234',
      ),
    };
    const vectors = <int, List<String>>{
      59: ['94287082', '46119246', '90693936'],
      1111111109: ['07081804', '68084774', '25091201'],
      1234567890: ['89005924', '91819424', '93441116'],
      20000000000: ['65353130', '77737706', '47863826'],
    };
    test('test vectors', () {
      vectors.forEach((seconds, codes) {
        final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        for (final (i, alg) in OtpAlgorithm.values.indexed) {
          expect(
            Otp.totp(keys[alg]!, time, digits: 8, algorithm: alg),
            codes[i],
            reason: '$alg at $seconds',
          );
        }
      });
    });

    test('remaining seconds', () {
      final t = DateTime.fromMillisecondsSinceEpoch(61 * 1000);
      expect(Otp.remaining(t, 30), 29);
    });

    test('steam codes use the steam alphabet', () {
      final code = Otp.generate(
        secret: 'JBSWY3DPEHPK3PXP',
        type: OtpType.steam,
        time: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      expect(code, hasLength(5));
      expect(RegExp(r'^[23456789BCDFGHJKMNPQRTVWXY]{5}$').hasMatch(code), true);
    });
  });

  group('otpauth URIs', () {
    test('parses the key uri format', () {
      final e = OtpAuthUri.parse(
        'otpauth://totp/ACME%20Co:john.doe@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ'
        '&issuer=ACME%20Co&algorithm=SHA256&digits=8&period=60',
      );
      expect(e.issuer, 'ACME Co');
      expect(e.account, 'john.doe@example.com');
      expect(e.algorithm, OtpAlgorithm.sha256);
      expect(e.digits, 8);
      expect(e.period, 60);
    });

    test('label without issuer and hotp', () {
      final e = OtpAuthUri.parse(
        'otpauth://hotp/alice?secret=JBSWY3DPEHPK3PXP&counter=7',
      );
      expect(e.issuer, '');
      expect(e.account, 'alice');
      expect(e.type, OtpType.hotp);
      expect(e.counter, 7);
    });

    test('round trip', () {
      const e = OtpEntry(
        issuer: 'Git Hub',
        account: 'me:you',
        secret: 'JBSWY3DPEHPK3PXP',
        digits: 8,
        period: 45,
        algorithm: OtpAlgorithm.sha512,
      );
      final back = OtpAuthUri.parse(OtpAuthUri.build(e));
      expect(back.toJson(), e.toJson());
    });

    test('rejects broken links', () {
      expect(() => OtpAuthUri.parse('https://x'), throwsFormatException);
      expect(() => OtpAuthUri.parse('otpauth://totp/x'), throwsFormatException);
      expect(
        () => OtpAuthUri.parse('otpauth://totp/x?secret=A1'),
        throwsFormatException,
      );
    });
  });

  group('Google Authenticator migration', () {
    test('round trip', () {
      const entries = [
        OtpEntry(issuer: 'GitHub', account: 'octo', secret: 'JBSWY3DPEHPK3PXP'),
        OtpEntry(
          issuer: '',
          account: 'counter',
          secret: 'GEZDGNBVGY3TQOJQ',
          type: OtpType.hotp,
          counter: 3,
          digits: 8,
          algorithm: OtpAlgorithm.sha256,
        ),
      ];
      final uris = GoogleMigration.build(entries);
      expect(uris, hasLength(1));
      final back = GoogleMigration.parse(uris.single);
      expect(
        [for (final e in back) e.toJson()],
        [for (final e in entries) e.toJson()],
      );
    });

    test('knows the position of a code in its series', () {
      final entries = [
        for (var i = 0; i < 20; i++)
          OtpEntry(issuer: 'S$i', account: 'a', secret: 'JBSWY3DPEHPK3PXP'),
      ];
      final uris = GoogleMigration.build(entries);
      expect(uris, hasLength(3));
      final batches = uris.map(GoogleMigration.batch).toList();
      expect([for (final b in batches) b!.index], [0, 1, 2]);
      expect(batches.every((b) => b!.size == 3), isTrue);
      expect(batches.map((b) => b!.id).toSet(), hasLength(1));
      expect(GoogleMigration.batch('otpauth://totp/x?secret=A'), isNull);
    });

    test('parses a hand-made transfer payload', () {
      // One TOTP account "Example:alice@example.com", encoded by hand.
      const uri =
          'otpauth-migration://offline?data=CjYKCkhlbGxvId6tvu8SGUV4YW1wbGU6YWxpY2VAZXhhbXBsZS5jb20aB0V4YW1wbGUgASgBMAIQARgBIAAoh61L';
      final entries = GoogleMigration.parse(uri);
      expect(entries, hasLength(1));
      expect(entries.single.issuer, 'Example');
      expect(entries.single.account, 'alice@example.com');
      expect(entries.single.secret, 'JBSWY3DPEHPK3PXP');
    });
  });
}
