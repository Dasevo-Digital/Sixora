import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;

import 'base32.dart';

enum OtpType {
  totp,
  hotp,

  /// Steam Guard: TOTP with SHA-1, 30 s and a five character alphabet.
  steam;

  static OtpType parse(String? value) => switch (value?.toLowerCase()) {
    'hotp' => hotp,
    'steam' => steam,
    _ => totp,
  };
}

enum OtpAlgorithm {
  sha1,
  sha256,
  sha512;

  static OtpAlgorithm parse(String? value) =>
      switch (value?.toUpperCase().replaceAll('-', '')) {
        'SHA256' => sha256,
        'SHA512' => sha512,
        _ => sha1,
      };

  String get label => switch (this) {
    sha1 => 'SHA1',
    sha256 => 'SHA256',
    sha512 => 'SHA512',
  };

  c.Hash get _hash => switch (this) {
    sha1 => c.sha1,
    sha256 => c.sha256,
    sha512 => c.sha512,
  };
}

/// HOTP (RFC 4226) and TOTP (RFC 6238) code generation.
abstract final class Otp {
  static const _steamAlphabet = '23456789BCDFGHJKMNPQRTVWXY';

  /// Raw truncated HOTP value for [counter].
  static int _truncate(List<int> key, int counter, OtpAlgorithm algorithm) {
    final message = ByteData(8)..setUint64(0, counter);
    final digest = c.Hmac(
      algorithm._hash,
      key,
    ).convert(message.buffer.asUint8List()).bytes;
    final offset = digest.last & 0x0f;
    return ((digest[offset] & 0x7f) << 24) |
        (digest[offset + 1] << 16) |
        (digest[offset + 2] << 8) |
        digest[offset + 3];
  }

  static String hotp(
    List<int> key,
    int counter, {
    int digits = 6,
    OtpAlgorithm algorithm = OtpAlgorithm.sha1,
  }) {
    final value = _truncate(key, counter, algorithm);
    var mod = 1;
    for (var i = 0; i < digits; i++) {
      mod *= 10;
    }
    return (value % mod).toString().padLeft(digits, '0');
  }

  static String steam(List<int> key, int counter) {
    var value = _truncate(key, counter, OtpAlgorithm.sha1);
    final out = StringBuffer();
    for (var i = 0; i < 5; i++) {
      out.write(_steamAlphabet[value % _steamAlphabet.length]);
      value ~/= _steamAlphabet.length;
    }
    return out.toString();
  }

  static int timeStep(DateTime time, int period) =>
      time.millisecondsSinceEpoch ~/ 1000 ~/ period;

  /// Seconds until the code for [time] expires.
  static int remaining(DateTime time, int period) =>
      period - (time.millisecondsSinceEpoch ~/ 1000) % period;

  static String totp(
    List<int> key,
    DateTime time, {
    int digits = 6,
    int period = 30,
    OtpAlgorithm algorithm = OtpAlgorithm.sha1,
  }) => hotp(key, timeStep(time, period), digits: digits, algorithm: algorithm);

  /// Code for an entry described by its parameters; [secret] is base32.
  static String generate({
    required String secret,
    required OtpType type,
    OtpAlgorithm algorithm = OtpAlgorithm.sha1,
    int digits = 6,
    int period = 30,
    int counter = 0,
    DateTime? time,
  }) {
    final key = Base32.decode(secret);
    final now = time ?? DateTime.now();
    return switch (type) {
      OtpType.hotp => hotp(key, counter, digits: digits, algorithm: algorithm),
      OtpType.steam => steam(key, timeStep(now, 30)),
      OtpType.totp => totp(
        key,
        now,
        digits: digits,
        period: period,
        algorithm: algorithm,
      ),
    };
  }
}
