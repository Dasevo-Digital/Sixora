import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import '../environment.dart';

/// Secrets of this device: the session token and, if quick unlock is
/// enabled, the user key.
///
/// They live in the operating system's keystore (Keychain, Android
/// Keystore, Windows Credential Manager, Secret Service on Linux) in a
/// single entry: on macOS without an Apple team signature every entry asks
/// for permission again after each update.
///
/// Only Linux may lack a keystore. Then the token goes to a file readable
/// only by the user and quick unlock is not offered. Integration tests
/// (SIXORA_ENV=test) always use such a file.
class SecretStore {
  SecretStore._(this._storage, this._fallback);

  final FlutterSecureStorage? _storage;
  final File? _fallback;
  Map<String, String> _values = {};

  bool get secure => _storage != null;

  static Future<SecretStore> open(Directory dataDir) async {
    // Automated tests run unattended: the keychain may ask for the login
    // password after every rebuild, so they keep their throwaway secrets
    // in their own data folder.
    if (AppEnv.name == 'test') return _fileStore(dataDir);
    const storage = FlutterSecureStorage(
      // Legacy keychain on macOS: needs no Keychain Sharing entitlement or
      // provisioning profile, so ad-hoc signed builds work.
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
      // Never migrates to another device via backups.
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
    try {
      final raw = await storage.read(key: AppEnv.secretsEntry);
      final store = SecretStore._(storage, null);
      store._values = _decode(raw);
      return store;
    } catch (e) {
      if (!Platform.isLinux) rethrow;
      debugPrint('Kein Schlüsselbund verfügbar: $e');
      return _fileStore(dataDir);
    }
  }

  /// For widget tests: a file in [dataDir], never the keystore.
  static SecretStore inFolder(Directory dataDir) => _fileStore(dataDir);

  static SecretStore _fileStore(Directory dataDir) {
    final file = File(p.join(dataDir.path, 'secrets.json'));
    final store = SecretStore._(null, file);
    if (file.existsSync()) store._values = _decode(file.readAsStringSync());
    return store;
  }

  static Map<String, String> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } on Object {
      return {};
    }
  }

  String? operator [](String key) => _values[key];

  Future<void> set(String key, String? value) async {
    if (value == null) {
      if (!_values.containsKey(key)) return;
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    await _persist();
  }

  Future<void> clear() async {
    _values = {};
    await _persist();
  }

  Future<void> _persist() async {
    final raw = jsonEncode(_values);
    if (_storage != null) {
      if (_values.isEmpty) {
        await _storage.delete(key: AppEnv.secretsEntry);
      } else {
        await _storage.write(key: AppEnv.secretsEntry, value: raw);
      }
      return;
    }
    final file = _fallback!;
    if (_values.isEmpty) {
      if (file.existsSync()) file.deleteSync();
      return;
    }
    // Restrict the permissions before the token is written.
    if (!file.existsSync()) {
      file.createSync(recursive: true);
      await Process.run('chmod', ['600', file.path]);
    }
    file.writeAsStringSync(raw, flush: true);
  }
}
