import 'base32.dart';
import 'entry.dart';
import 'otp.dart';

/// Parsing and building of `otpauth://` URIs (Key Uri Format).
abstract final class OtpAuthUri {
  static bool looksLike(String text) =>
      text.trim().toLowerCase().startsWith('otpauth://');

  /// Throws [FormatException] for anything that is not a usable otpauth URI.
  static OtpEntry parse(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'otpauth') {
      throw const FormatException('Kein otpauth-Link');
    }
    final params = <String, String>{
      for (final e in uri.queryParameters.entries) e.key.toLowerCase(): e.value,
    };
    final host = uri.host.toLowerCase();
    var type = switch (host) {
      'totp' => OtpType.totp,
      'hotp' => OtpType.hotp,
      'steam' => OtpType.steam,
      _ => throw FormatException('Unbekannter Typ „$host“'),
    };
    if (params['encoder']?.toLowerCase() == 'steam') type = OtpType.steam;

    final secret = Base32.normalize(params['secret'] ?? '');
    if (secret.isEmpty) throw const FormatException('Schlüssel fehlt');

    // The label is "Issuer:account" or just "account"; the issuer parameter
    // wins when both are present.
    var label = uri.pathSegments.isEmpty
        ? ''
        : Uri.decodeComponent(uri.pathSegments.join('/'));
    label = label.trim();
    var issuer = params['issuer']?.trim() ?? '';
    var account = label;
    final colon = label.indexOf(':');
    if (colon >= 0) {
      final prefix = label.substring(0, colon).trim();
      account = label.substring(colon + 1).trim();
      if (issuer.isEmpty) issuer = prefix;
    }

    final entry = OtpEntry(
      issuer: issuer,
      account: account,
      secret: secret,
      type: type,
      algorithm: OtpAlgorithm.parse(params['algorithm']),
      digits: int.tryParse(params['digits'] ?? '') ?? 6,
      period: int.tryParse(params['period'] ?? '') ?? 30,
      counter: int.tryParse(params['counter'] ?? '') ?? 0,
    );
    entry.validate();
    return entry;
  }

  static String build(OtpEntry entry) {
    final label = entry.issuer.isEmpty
        ? entry.account
        : '${entry.issuer}:${entry.account}';
    final params = <String, String>{
      'secret': entry.secret,
      if (entry.issuer.isNotEmpty) 'issuer': entry.issuer,
      if (entry.type != OtpType.steam) ...{
        'algorithm': entry.algorithm.label,
        'digits': '${entry.digits}',
      },
      if (entry.type == OtpType.totp) 'period': '${entry.period}',
      if (entry.type == OtpType.hotp) 'counter': '${entry.counter}',
      if (entry.type == OtpType.steam) 'encoder': 'steam',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final host = entry.type == OtpType.hotp ? 'hotp' : 'totp';
    return 'otpauth://$host/${Uri.encodeComponent(label)}?$query';
  }
}
