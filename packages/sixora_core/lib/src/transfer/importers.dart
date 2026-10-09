import 'dart:convert';
import 'dart:typed_data';

import '../crypto/account_keys.dart';
import '../crypto/vault_crypto.dart';
import '../otp/base32.dart';
import '../otp/entry.dart';
import '../otp/otp.dart';
import '../otp/otpauth.dart';
import 'google_migration.dart';

/// Result of reading an import file or code.
class ImportResult {
  ImportResult(this.source, this.entries, {this.skipped = 0});
  final String source;
  final List<OtpEntry> entries;

  /// Items that were recognized but could not be used.
  final int skipped;
}

class NeedsPasswordException implements Exception {
  const NeedsPasswordException();
}

/// Detects and reads the export formats of common authenticator apps.
///
/// Supported: Sixora backups (encrypted), Aegis (unencrypted JSON), 2FAuth
/// JSON, 2FAS (.2fas without password), Bitwarden (JSON and CSV), andOTP
/// (unencrypted JSON), FreeOTP+ (JSON), Google Authenticator transfer codes
/// and any text containing `otpauth://` links (e.g. Ente Auth's export).
abstract final class Importers {
  static Future<ImportResult> read(String text, {String? password}) async {
    final trimmed = text.trim();
    if (GoogleMigration.looksLike(trimmed) && !trimmed.contains('\n')) {
      return ImportResult(
        'Google Authenticator',
        GoogleMigration.parse(trimmed),
      );
    }
    Object? json;
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        json = jsonDecode(trimmed);
      } on FormatException {
        json = null;
      }
    }
    if (json is Map) {
      if (json['format'] == SixoraBackup.format) {
        if (password == null) throw const NeedsPasswordException();
        return ImportResult(
          'Sixora',
          await SixoraBackup.decrypt(trimmed, password),
        );
      }
      if (json['db'] is Map && json['header'] is Map) return _aegis(json);
      if (json['db'] is String) {
        throw const FormatException(
          'Verschlüsselte Aegis-Sicherung: bitte in Aegis unverschlüsselt '
          'exportieren',
        );
      }
      if (json['data'] is List && '${json['app']}'.contains('2fauth')) {
        return _twoFauth(json);
      }
      if (json['services'] is List && json.containsKey('schemaVersion')) {
        if ((json['services'] as List).isEmpty &&
            json['servicesEncrypted'] is String) {
          throw const FormatException(
            'Verschlüsselte 2FAS-Sicherung: bitte in 2FAS ohne Passwort '
            'exportieren',
          );
        }
        return _twoFas(json);
      }
      if (json['items'] is List && json.containsKey('encrypted')) {
        return _bitwarden(json);
      }
      if (json['encrypted'] == true) {
        throw const FormatException(
          'Verschlüsselter Bitwarden-Export: bitte als „.json“ ohne '
          'Verschlüsselung exportieren',
        );
      }
      if (json['tokens'] is List) return _freeOtp(json);
      if (json['encryptedData'] is String && json['kdfParams'] is Map) {
        throw const FormatException(
          'Verschlüsselte Ente-Auth-Sicherung: bitte unverschlüsselt (als '
          'Textdatei) exportieren',
        );
      }
    }
    if (json is List &&
        json.isNotEmpty &&
        json.first is Map &&
        (json.first as Map).containsKey('secret')) {
      return _andOtp(json);
    }
    final firstLine = trimmed.split('\n').first;
    if (firstLine.contains('login_totp')) return _bitwardenCsv(trimmed);
    return _uris(trimmed);
  }

  static ImportResult _uris(String text) {
    final found = RegExp(
      r'otpauth(?:-migration)?://[^\s"<>]+',
      caseSensitive: false,
    ).allMatches(text);
    final entries = <OtpEntry>[];
    var skipped = 0;
    for (final m in found) {
      final uri = m.group(0)!.replaceAll(r'&', '&').replaceAll(r'\/', '/');
      try {
        if (GoogleMigration.looksLike(uri)) {
          entries.addAll(GoogleMigration.parse(uri));
        } else {
          entries.add(OtpAuthUri.parse(uri));
        }
      } on FormatException {
        skipped++;
      }
    }
    if (entries.isEmpty && skipped == 0) {
      throw const FormatException('Keine Konten in der Datei gefunden');
    }
    return ImportResult('otpauth-Links', entries, skipped: skipped);
  }

  static ImportResult _aegis(Map json) {
    final db = (json['db'] as Map).cast<String, Object?>();
    final groupNames = <String, String>{
      for (final g in db['groups'] as List? ?? const [])
        if (g is Map) '${g['uuid']}': '${g['name']}',
    };
    final entries = <OtpEntry>[];
    var skipped = 0;
    for (final raw in db['entries'] as List? ?? const []) {
      try {
        final e = (raw as Map).cast<String, Object?>();
        final info = (e['info'] as Map).cast<String, Object?>();
        final type = switch (e['type']) {
          'totp' => OtpType.totp,
          'hotp' => OtpType.hotp,
          'steam' => OtpType.steam,
          _ => throw const FormatException('Typ nicht unterstützt'),
        };
        final groups = (e['groups'] as List? ?? const [])
            .map((id) => groupNames['$id'])
            .whereType<String>();
        final entry = OtpEntry(
          issuer: '${e['issuer'] ?? ''}',
          account: '${e['name'] ?? ''}',
          secret: Base32.normalize('${info['secret']}'),
          type: type,
          algorithm: OtpAlgorithm.parse(info['algo'] as String?),
          digits: (info['digits'] as num?)?.toInt() ?? 6,
          period: (info['period'] as num?)?.toInt() ?? 30,
          counter: (info['counter'] as num?)?.toInt() ?? 0,
          group: groups.isEmpty ? '${e['group'] ?? ''}' : groups.first,
          favorite: e['favorite'] == true,
          notes: '${e['note'] ?? ''}',
        );
        entry.validate();
        entries.add(entry);
      } catch (_) {
        skipped++;
      }
    }
    return ImportResult('Aegis', entries, skipped: skipped);
  }

  static ImportResult _twoFauth(Map json) {
    final entries = <OtpEntry>[];
    var skipped = 0;
    for (final raw in json['data'] as List) {
      try {
        final e = (raw as Map).cast<String, Object?>();
        final type = switch (e['otp_type']) {
          'totp' => OtpType.totp,
          'hotp' => OtpType.hotp,
          'steamtotp' => OtpType.steam,
          _ => throw const FormatException('Typ nicht unterstützt'),
        };
        final entry = OtpEntry(
          issuer: '${e['service'] ?? ''}',
          account: '${e['account'] ?? ''}',
          secret: Base32.normalize('${e['secret']}'),
          type: type,
          algorithm: OtpAlgorithm.parse(e['algorithm'] as String?),
          digits: (e['digits'] as num?)?.toInt() ?? 6,
          period: (e['period'] as num?)?.toInt() ?? 30,
          counter: (e['counter'] as num?)?.toInt() ?? 0,
        );
        entry.validate();
        entries.add(entry);
      } catch (_) {
        skipped++;
      }
    }
    return ImportResult('2FAuth', entries, skipped: skipped);
  }
}

/// 2FAS: `.2fas` file exported without a password.
ImportResult _twoFas(Map json) {
  final groups = <String, String>{
    for (final g in json['groups'] as List? ?? const [])
      if (g is Map) '${g['id']}': '${g['name']}',
  };
  final entries = <OtpEntry>[];
  var skipped = 0;
  for (final raw in json['services'] as List) {
    try {
      final service = (raw as Map).cast<String, Object?>();
      final otp = (service['otp'] as Map? ?? const {}).cast<String, Object?>();
      final type = switch ('${otp['tokenType'] ?? 'TOTP'}'.toUpperCase()) {
        'TOTP' => OtpType.totp,
        'HOTP' => OtpType.hotp,
        'STEAM' => OtpType.steam,
        _ => throw const FormatException('Typ nicht unterstützt'),
      };
      final issuer = '${otp['issuer'] ?? service['name'] ?? ''}';
      final entry = OtpEntry(
        issuer: issuer.isEmpty ? '${service['name'] ?? ''}' : issuer,
        account: '${otp['account'] ?? otp['label'] ?? ''}',
        secret: Base32.normalize('${service['secret']}'),
        type: type,
        algorithm: OtpAlgorithm.parse(otp['algorithm'] as String?),
        digits: (otp['digits'] as num?)?.toInt() ?? 6,
        period: (otp['period'] as num?)?.toInt() ?? 30,
        counter: (otp['counter'] as num?)?.toInt() ?? 0,
        group: groups['${service['groupId']}'] ?? '',
      );
      entry.validate();
      entries.add(entry);
    } catch (_) {
      skipped++;
    }
  }
  return ImportResult('2FAS', entries, skipped: skipped);
}

/// Bitwarden: one login per item; `login.totp` holds an otpauth link, a
/// `steam://` secret or the bare Base32 secret.
OtpEntry _bitwardenTotp(String totp, String name, String user) {
  final value = totp.trim();
  if (value.toLowerCase().startsWith('otpauth://')) {
    final entry = OtpAuthUri.parse(value);
    // Bitwarden keeps the item name; the link may lack an issuer.
    return entry.issuer.isEmpty ? entry.copyWith(issuer: name) : entry;
  }
  final steam = value.toLowerCase().startsWith('steam://');
  return OtpEntry(
    issuer: name,
    account: user,
    secret: Base32.normalize(steam ? value.substring(8) : value),
    type: steam ? OtpType.steam : OtpType.totp,
  );
}

ImportResult _bitwarden(Map json) {
  final folders = <String, String>{
    for (final f in json['folders'] as List? ?? const [])
      if (f is Map) '${f['id']}': '${f['name']}',
  };
  final entries = <OtpEntry>[];
  var skipped = 0;
  for (final raw in json['items'] as List) {
    if (raw is! Map) continue;
    final login = raw['login'];
    final totp = login is Map ? login['totp'] : null;
    if (totp is! String || totp.trim().isEmpty) continue;
    try {
      final entry =
          _bitwardenTotp(
            totp,
            '${raw['name'] ?? ''}',
            '${login['username'] ?? ''}',
          ).copyWith(
            group: folders['${raw['folderId']}'] ?? '',
            favorite: raw['favorite'] == true,
          );
      entry.validate();
      entries.add(entry);
    } catch (_) {
      skipped++;
    }
  }
  if (entries.isEmpty && skipped == 0) {
    throw const FormatException('Keine Konten in der Datei gefunden');
  }
  return ImportResult('Bitwarden', entries, skipped: skipped);
}

/// Bitwarden's CSV export (columns name, login_username, login_totp, …).
ImportResult _bitwardenCsv(String text) {
  final rows = _csv(text);
  final head = rows.first;
  final name = head.indexOf('name');
  final user = head.indexOf('login_username');
  final totp = head.indexOf('login_totp');
  final folder = head.indexOf('folder');
  final entries = <OtpEntry>[];
  var skipped = 0;
  for (final row in rows.skip(1)) {
    String cell(int i) => i >= 0 && i < row.length ? row[i] : '';
    if (cell(totp).trim().isEmpty) continue;
    try {
      final entry = _bitwardenTotp(
        cell(totp),
        cell(name),
        cell(user),
      ).copyWith(group: cell(folder));
      entry.validate();
      entries.add(entry);
    } catch (_) {
      skipped++;
    }
  }
  if (entries.isEmpty && skipped == 0) {
    throw const FormatException('Keine Konten in der Datei gefunden');
  }
  return ImportResult('Bitwarden', entries, skipped: skipped);
}

/// RFC 4180 CSV: quoted fields with "" for a quote, line breaks inside.
List<List<String>> _csv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

/// andOTP: unencrypted JSON export, a list of tokens.
ImportResult _andOtp(List json) {
  final entries = <OtpEntry>[];
  var skipped = 0;
  for (final raw in json) {
    try {
      final e = (raw as Map).cast<String, Object?>();
      final type = switch ('${e['type'] ?? 'TOTP'}'.toUpperCase()) {
        'TOTP' => OtpType.totp,
        'HOTP' => OtpType.hotp,
        'STEAM' => OtpType.steam,
        _ => throw const FormatException('Typ nicht unterstützt'),
      };
      final tags = (e['tags'] as List? ?? const []).whereType<String>();
      var issuer = '${e['issuer'] ?? ''}';
      var account = '${e['label'] ?? ''}';
      // Older versions: "Issuer:account" in the label.
      if (issuer.isEmpty && account.contains(':')) {
        final at = account.indexOf(':');
        issuer = account.substring(0, at).trim();
        account = account.substring(at + 1).trim();
      }
      final entry = OtpEntry(
        issuer: issuer,
        account: account,
        secret: Base32.normalize('${e['secret']}'),
        type: type,
        algorithm: OtpAlgorithm.parse(e['algorithm'] as String?),
        digits: (e['digits'] as num?)?.toInt() ?? 6,
        period: (e['period'] as num?)?.toInt() ?? 30,
        counter: (e['counter'] as num?)?.toInt() ?? 0,
        group: tags.isEmpty ? '' : tags.first,
      );
      entry.validate();
      entries.add(entry);
    } catch (_) {
      skipped++;
    }
  }
  return ImportResult('andOTP', entries, skipped: skipped);
}

/// FreeOTP+: JSON with the secret as signed bytes.
ImportResult _freeOtp(Map json) {
  final entries = <OtpEntry>[];
  var skipped = 0;
  for (final raw in json['tokens'] as List) {
    try {
      final e = (raw as Map).cast<String, Object?>();
      final bytes = [
        for (final b in e['secret'] as List) (b as num).toInt() & 0xff,
      ];
      final type = switch ('${e['type'] ?? 'TOTP'}'.toUpperCase()) {
        'TOTP' => OtpType.totp,
        'HOTP' => OtpType.hotp,
        _ => throw const FormatException('Typ nicht unterstützt'),
      };
      final issuer = '${e['issuerExt'] ?? ''}';
      final entry = OtpEntry(
        issuer: issuer.isEmpty ? '${e['issuerInt'] ?? ''}' : issuer,
        account: '${e['label'] ?? ''}',
        secret: Base32.encode(bytes),
        type: type,
        algorithm: OtpAlgorithm.parse(e['algo'] as String?),
        digits: (e['digits'] as num?)?.toInt() ?? 6,
        period: (e['period'] as num?)?.toInt() ?? 30,
        counter: (e['counter'] as num?)?.toInt() ?? 0,
      );
      entry.validate();
      entries.add(entry);
    } catch (_) {
      skipped++;
    }
  }
  return ImportResult('FreeOTP+', entries, skipped: skipped);
}

/// Password protected backup file, independent of the server account.
/// The key of a backup password (Argon2id with its own salt).
class BackupKey {
  BackupKey({required this.kdf, required this.salt, required this.key});
  final KdfParams kdf;
  final String salt;
  final Uint8List key;

  static Future<BackupKey> derive(
    String password, {
    KdfParams kdf = KdfParams.recommended,
  }) async {
    final salt = VaultCrypto.newSaltB64();
    final keys = await derivePasswordKeysAsync(password, salt, kdf);
    return BackupKey(kdf: kdf, salt: salt, key: keys.kek);
  }
}

abstract final class SixoraBackup {
  static const format = 'sixora-backup';
  static const _aad = 'sixora-backup-v1';

  static Future<String> encrypt(
    List<OtpEntry> entries,
    String password, {
    KdfParams kdf = KdfParams.recommended,
  }) async =>
      encryptWithKey(entries, await BackupKey.derive(password, kdf: kdf));

  /// Same file as [encrypt], with a key derived earlier: automatic backups
  /// need no password prompt and no Argon2 run each time.
  static Future<String> encryptWithKey(
    List<OtpEntry> entries,
    BackupKey key,
  ) async {
    final payload = jsonEncode({
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'entries': [for (final e in entries) e.toJson()],
    });
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': 1,
      'kdf': key.kdf.toJson(),
      'salt': key.salt,
      'data': await VaultCrypto.encryptString(key.key, payload, aad: _aad),
    });
  }

  static Map<String, Object?> _header(String text) {
    final json = (jsonDecode(text) as Map).cast<String, Object?>();
    if (json['format'] != format || json['version'] != 1) {
      throw const FormatException('Unbekanntes Sicherungsformat');
    }
    return json;
  }

  static Future<List<OtpEntry>> decrypt(String text, String password) async {
    final json = _header(text);
    final keys = await derivePasswordKeysAsync(
      password,
      json['salt'] as String,
      KdfParams.fromJson((json['kdf'] as Map).cast()),
    );
    return _open(json, keys.kek);
  }

  /// Opens a file written with [key] (automatic backups check their own
  /// files this way, without asking for the password).
  static Future<List<OtpEntry>> decryptWithKey(
    String text,
    BackupKey key,
  ) async {
    final json = _header(text);
    if (json['salt'] != key.salt) {
      throw const CryptoException(
        'Diese Sicherung wurde mit einem anderen Passwort erstellt',
      );
    }
    return _open(json, key.key);
  }

  static Future<List<OtpEntry>> _open(
    Map<String, Object?> json,
    List<int> key,
  ) async {
    final String clear;
    try {
      clear = await VaultCrypto.decryptString(
        key,
        json['data'] as String,
        aad: _aad,
      );
    } on CryptoException {
      throw const CryptoException('Passwort der Sicherung ist falsch');
    }
    final payload = (jsonDecode(clear) as Map).cast<String, Object?>();
    return [
      for (final e in payload['entries'] as List)
        OtpEntry.fromJson((e as Map).cast()),
    ];
  }

  /// Plain text export: one otpauth link per line. Unencrypted!
  static String plainUris(List<OtpEntry> entries) =>
      '${entries.map(OtpAuthUri.build).join('\n')}\n';
}
