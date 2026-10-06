import 'dart:typed_data';

/// RFC 4648 base32, as used by otpauth secrets.
abstract final class Base32 {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Decodes a secret leniently: case, spaces, dashes and padding are
  /// ignored, because services print secrets in every imaginable format.
  /// Throws [FormatException] on any other character.
  static Uint8List decode(String input) {
    final clean = normalize(input);
    if (clean.isEmpty) throw const FormatException('Leerer Schlüssel');
    final out = BytesBuilder(copy: false);
    var buffer = 0;
    var bits = 0;
    for (final unit in clean.codeUnits) {
      final value = _alphabet.indexOf(String.fromCharCode(unit));
      if (value < 0) {
        throw FormatException('Ungültiges Zeichen im Schlüssel', input);
      }
      buffer = (buffer << 5) | value;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.addByte((buffer >> bits) & 0xff);
      }
      buffer &= (1 << bits) - 1;
    }
    return out.takeBytes();
  }

  static String encode(List<int> bytes) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in bytes) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        out.write(_alphabet[(buffer >> bits) & 31]);
      }
      buffer &= (1 << bits) - 1;
    }
    if (bits > 0) out.write(_alphabet[(buffer << (5 - bits)) & 31]);
    return out.toString();
  }

  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[\s\-=]'), '');

  static bool isValid(String input) {
    try {
      decode(input);
      return true;
    } on FormatException {
      return false;
    }
  }
}
