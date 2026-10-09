import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:local_auth_darwin/types/auth_messages_macos.dart';

import '../environment.dart';
import 'secret_store.dart';

/// Result of a biometric unlock attempt.
enum BiometricResult {
  unlocked,
  cancelled,
  invalidated,

  /// "Master-Passwort" in the system dialog: the user wants to type the
  /// Sixora master password instead.
  password,
}

/// Keeps the user key for unlocking with Face ID, Touch ID, a fingerprint
/// or Windows Hello.
///
/// * **iOS:** a Keychain item bound to the currently enrolled biometrics
///   (`biometryCurrentSet`). iOS itself asks for Face ID or Touch ID before
///   it hands the item out; new fingers or faces invalidate it.
/// * **Android (9+):** encrypted with a hardware Keystore key that needs a
///   strong biometric for every use and is invalidated by new enrolments.
/// * **macOS, Windows:** the app asks for Touch ID or Windows Hello and then
///   reads the key from the normal keystore entry. Binding it to biometrics
///   needs the data protection keychain, which requires a provisioning
///   profile on macOS.
class BiometricVault {
  BiometricVault._(this.kind, this._secrets);

  /// Display name of the method, e.g. "Face ID"; null if unavailable.
  final String? kind;
  final SecretStore _secrets;
  final _auth = LocalAuthentication();

  bool get available => kind != null;

  /// Whether the operating system enforces the biometric check itself.
  static bool get hardwareBound => Platform.isIOS || Platform.isAndroid;

  static String get _key => '${AppEnv.secretsEntry}.biometric';

  static final _bound = FlutterSecureStorage(
    iOptions: const IOSOptions(
      accountName: 'sixora.biometric',
      accessibility: KeychainAccessibility.unlocked_this_device,
      accessControlFlags: [AccessControlFlag.biometryCurrentSet],
    ),
    aOptions: AndroidOptions.biometric(
      enforceBiometrics: true,
      // Without this the plugin keeps the cipher unlocked for the whole
      // process: after the first unlock, later ones would not ask again.
      requireBiometricsPerOperation: true,
      biometricType: AndroidBiometricType.strongBiometricOnly,
      storageNamespace: 'sixora_biometric_${AppEnv.name}',
      biometricPromptTitle: 'Sixora entsperren',
      biometricPromptNegativeButton: 'Master-Passwort',
    ),
  );

  static Future<BiometricVault> open(SecretStore secrets) async =>
      BiometricVault._(await _detect(secrets), secrets);

  static Future<String?> _detect(SecretStore secrets) async {
    if (!secrets.secure || Platform.isLinux) return null;
    try {
      final auth = LocalAuthentication();
      if (Platform.isAndroid) {
        final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        if (sdk < 28) return null;
      }
      if (Platform.isWindows) {
        return await auth.isDeviceSupported() ? 'Windows Hello' : null;
      }
      final types = await auth.getAvailableBiometrics();
      if (types.isEmpty) return null;
      if (Platform.isIOS || Platform.isMacOS) {
        return types.contains(BiometricType.face) ? 'Face ID' : 'Touch ID';
      }
      // Android: only strong biometrics can unlock the Keystore key.
      if (!types.contains(BiometricType.strong) &&
          !types.contains(BiometricType.fingerprint)) {
        return null;
      }
      return types.contains(BiometricType.fingerprint)
          ? 'Fingerabdruck'
          : 'Biometrie';
    } on Object {
      return null;
    }
  }

  /// Stores [userKey]; the user confirms with biometrics.
  Future<bool> enable(Uint8List userKey) async {
    final value = base64.encode(userKey);
    if (hardwareBound) {
      await _bound.write(key: _key, value: value);
      // Reading it back shows the system prompt once: proof that it works.
      return await _bound.read(key: _key) == value;
    }
    if (await _authenticate('Entsperren mit $kind einrichten') !=
        BiometricResult.unlocked) {
      return false;
    }
    await _secrets.set('quickKey', value);
    return true;
  }

  Future<void> disable() async {
    if (hardwareBound) {
      try {
        await _bound.delete(key: _key);
      } on PlatformException {
        // Nothing stored.
      }
    }
    await _secrets.set('quickKey', null);
  }

  /// Reads the user key after a successful biometric check.
  Future<(BiometricResult, Uint8List?)> unlock() async {
    String? value;
    if (hardwareBound) {
      try {
        value = await _bound.read(key: _key);
      } on PlatformException catch (e) {
        if (!_invalidated(e)) return (BiometricResult.cancelled, null);
        await disable();
        return (BiometricResult.invalidated, null);
      }
      if (value == null) return (BiometricResult.invalidated, null);
    } else {
      final result = await _authenticate('Sixora entsperren');
      if (result != BiometricResult.unlocked) return (result, null);
      value = _secrets['quickKey'];
      if (value == null) return (BiometricResult.invalidated, null);
    }
    return (BiometricResult.unlocked, base64.decode(value));
  }

  /// The system dialog offers the Sixora master password as fallback, not
  /// the device password: the master password is the key to the vault, the
  /// device password only unlocks the device.
  static const _messages = [
    IOSAuthMessages(
      localizedFallbackTitle: 'Master-Passwort',
      cancelButton: 'Abbrechen',
    ),
    MacOSAuthMessages(
      localizedFallbackTitle: 'Master-Passwort',
      cancelButton: 'Abbrechen',
    ),
    AndroidAuthMessages(
      signInTitle: 'Sixora entsperren',
      cancelButton: 'Master-Passwort',
    ),
  ];

  Future<BiometricResult> _authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        authMessages: _messages,
        biometricOnly: !Platform.isWindows,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricResult.unlocked : BiometricResult.cancelled;
    } on LocalAuthException catch (e) {
      return e.code == LocalAuthExceptionCode.userRequestedFallback
          ? BiometricResult.password
          : BiometricResult.cancelled;
    } on PlatformException {
      return BiometricResult.cancelled;
    }
  }

  /// Only a key that is definitely unusable is removed (changed
  /// enrolment, missing item); a cancelled or failed prompt keeps it.
  static bool _invalidated(PlatformException e) {
    final text = '${e.code} ${e.message} ${e.details}'.toLowerCase();
    return text.contains('permanentlyinvalidated') ||
        text.contains('invalidated') ||
        text.contains('-25300') ||
        text.contains('not found') ||
        text.contains('notfound');
  }
}
