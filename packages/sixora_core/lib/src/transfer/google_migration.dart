import 'dart:convert';
import 'dart:typed_data';

import '../otp/base32.dart';
import '../otp/entry.dart';
import '../otp/otp.dart';

/// Google Authenticator's "Transfer accounts" QR codes
/// (`otpauth-migration://offline?data=…`), a small protobuf message.
abstract final class GoogleMigration {
  static bool looksLike(String text) =>
      text.trim().toLowerCase().startsWith('otpauth-migration://');

  static List<OtpEntry> parse(String text) {
    final uri = Uri.tryParse(text.trim());
    final data = uri?.queryParameters['data'];
    if (uri == null || data == null) {
      throw const FormatException('Kein Google-Authenticator-Export');
    }
    final Uint8List bytes;
    try {
      bytes = base64.decode(base64.normalize(data.replaceAll(' ', '+')));
    } on FormatException {
      throw const FormatException('Export-Daten sind beschädigt');
    }
    final entries = <OtpEntry>[];
    for (final field in _Reader(bytes).fields()) {
      if (field.number == 1 && field.bytes != null) {
        final entry = _parseParameters(field.bytes!);
        if (entry != null) entries.add(entry);
      }
    }
    return entries;
  }

  static OtpEntry? _parseParameters(Uint8List bytes) {
    List<int> secret = const [];
    var name = '';
    var issuer = '';
    var algorithm = OtpAlgorithm.sha1;
    var digits = 6;
    var type = OtpType.totp;
    var counter = 0;
    for (final f in _Reader(bytes).fields()) {
      switch (f.number) {
        case 1:
          secret = f.bytes ?? const [];
        case 2:
          name = utf8.decode(f.bytes ?? const [], allowMalformed: true);
        case 3:
          issuer = utf8.decode(f.bytes ?? const [], allowMalformed: true);
        case 4:
          algorithm = switch (f.value) {
            2 => OtpAlgorithm.sha256,
            3 => OtpAlgorithm.sha512,
            _ => OtpAlgorithm.sha1,
          };
        case 5:
          digits = f.value == 2 ? 8 : 6;
        case 6:
          type = f.value == 1 ? OtpType.hotp : OtpType.totp;
        case 7:
          counter = f.value ?? 0;
      }
    }
    if (secret.isEmpty) return null;
    var account = name;
    final colon = name.indexOf(':');
    if (colon >= 0) {
      final prefix = name.substring(0, colon).trim();
      if (issuer.isEmpty || prefix.toLowerCase() == issuer.toLowerCase()) {
        issuer = issuer.isEmpty ? prefix : issuer;
        account = name.substring(colon + 1).trim();
      }
    }
    return OtpEntry(
      issuer: issuer,
      account: account,
      secret: Base32.encode(secret),
      type: type,
      algorithm: algorithm,
      digits: digits,
      counter: counter,
    );
  }

  /// Builds migration URIs for Google Authenticator, at most [batchSize]
  /// accounts per QR code. Entries it cannot represent (Steam, 30 s periods
  /// other than the default, other digit counts) are skipped.
  static List<String> build(List<OtpEntry> entries, {int batchSize = 8}) {
    final usable = entries.where(canExport).toList();
    final batches = <String>[];
    final batchCount = (usable.length / batchSize).ceil();
    final batchId = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    for (var i = 0; i < batchCount; i++) {
      final w = _Writer();
      for (final e in usable.skip(i * batchSize).take(batchSize)) {
        final p = _Writer()
          ..bytes(1, Base32.decode(e.secret))
          ..string(2, e.account)
          ..string(3, e.issuer)
          ..varint(4, switch (e.algorithm) {
            OtpAlgorithm.sha1 => 1,
            OtpAlgorithm.sha256 => 2,
            OtpAlgorithm.sha512 => 3,
          })
          ..varint(5, e.digits == 8 ? 2 : 1)
          ..varint(6, e.type == OtpType.hotp ? 1 : 2);
        if (e.type == OtpType.hotp) p.varint(7, e.counter);
        w.bytes(1, p.takeBytes());
      }
      w
        ..varint(2, 1)
        ..varint(3, batchCount)
        ..varint(4, i)
        ..varint(5, batchId);
      final data = Uri.encodeComponent(base64.encode(w.takeBytes()));
      batches.add('otpauth-migration://offline?data=$data');
    }
    return batches;
  }

  static bool canExport(OtpEntry e) =>
      e.type != OtpType.steam &&
      (e.digits == 6 || e.digits == 8) &&
      (e.type == OtpType.hotp || e.period == 30);
}

class _Field {
  _Field(this.number, {this.value, this.bytes});
  final int number;
  final int? value;
  final Uint8List? bytes;
}

class _Reader {
  _Reader(this._data);
  final Uint8List _data;
  int _pos = 0;

  int _varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_pos >= _data.length || shift > 63) {
        throw const FormatException('Export-Daten sind beschädigt');
      }
      final b = _data[_pos++];
      result |= (b & 0x7f) << shift;
      if (b < 0x80) return result;
      shift += 7;
    }
  }

  Iterable<_Field> fields() sync* {
    while (_pos < _data.length) {
      final key = _varint();
      final number = key >> 3;
      switch (key & 7) {
        case 0:
          yield _Field(number, value: _varint());
        case 1:
          _pos += 8;
        case 2:
          final len = _varint();
          if (len < 0 || _pos + len > _data.length) {
            throw const FormatException('Export-Daten sind beschädigt');
          }
          yield _Field(
            number,
            bytes: Uint8List.sublistView(_data, _pos, _pos + len),
          );
          _pos += len;
        case 5:
          _pos += 4;
        default:
          throw const FormatException('Export-Daten sind beschädigt');
      }
    }
  }
}

class _Writer {
  final _out = BytesBuilder();

  void _rawVarint(int v) {
    var value = v;
    while (value >= 0x80) {
      _out.addByte((value & 0x7f) | 0x80);
      value >>= 7;
    }
    _out.addByte(value);
  }

  void varint(int number, int value) {
    _rawVarint(number << 3);
    _rawVarint(value);
  }

  void bytes(int number, List<int> value) {
    _rawVarint((number << 3) | 2);
    _rawVarint(value.length);
    _out.add(value);
  }

  void string(int number, String value) => bytes(number, utf8.encode(value));

  Uint8List takeBytes() => _out.takeBytes();
}
