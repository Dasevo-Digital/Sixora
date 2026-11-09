import 'dart:convert';
import 'dart:typed_data';

import 'package:sixora_core/sixora_core.dart';

import 'passkeys.dart';
import 'stored_account.dart';

/// The browser's key-value storage (`storage.local`, `storage.session`);
/// a map in tests.
abstract interface class Store {
  Future<String?> read(String key);

  /// null removes the key.
  Future<void> write(String key, String? value);
}

enum Stage { loading, setup, locked, unlocked }

/// A problem the user can act on; [code] picks the text.
class ExtensionError implements Exception {
  const ExtensionError(this.code);
  final String code;
  @override
  String toString() => code;
}

class ExtensionSettings {
  ExtensionSettings({this.autoLockMinutes = 15});

  /// 0: only when the browser closes.
  int autoLockMinutes;

  static const choices = [1, 5, 15, 60, 0];

  Map<String, Object?> toJson() => {'autoLockMinutes': autoLockMinutes};

  factory ExtensionSettings.fromJson(Map<String, Object?>? j) =>
      ExtensionSettings(autoLockMinutes: j?['autoLockMinutes'] as int? ?? 15);
}

/// State of the extension: signed in or not, locked or not, the codes.
///
/// It only reads: accounts are added and changed in the apps. The keys
/// live in memory and, while unlocked, in `storage.session`, which the
/// browser keeps in memory only and forgets when it closes; popups come
/// and go, so that is what keeps the extension unlocked between two.
class SixoraExtension {
  SixoraExtension({
    required this.local,
    required this.session,
    required this.device,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Store local;
  final Store session;

  /// The extension's key pair for the desktop app (see `AppUnlock`).
  static const linkKeyEntry = 'linkKey';
  final DeviceInfo device;
  final DateTime Function() _clock;

  Stage stage = Stage.loading;
  StoredAccount? stored;
  UnlockedKeys? _keys;
  List<Code> codes = const [];
  List<StoredPasskey> passkeys = const [];
  int unreadable = 0;
  ExtensionSettings settings = ExtensionSettings();

  /// Why the last sync failed (offline …); the list shows the stored state.
  Object? syncError;

  /// The server ended this session (signed out elsewhere, password
  /// changed): shown once on the setup page.
  bool signedOutRemotely = false;

  Future<Map<String, Object?>?> _readJson(Store store, String key) async {
    final text = await store.read(key);
    if (text == null) return null;
    try {
      return (jsonDecode(text) as Map).cast();
    } on FormatException {
      return null;
    }
  }

  Future<void> load() async {
    settings = ExtensionSettings.fromJson(await _readJson(local, 'settings'));
    final j = await _readJson(local, 'account');
    stored = j == null ? null : StoredAccount.fromJson(j);
    final s = stored;
    if (s == null) {
      stage = Stage.setup;
      return;
    }
    stage = Stage.locked;
    // Still unlocked from an earlier popup, within the auto-lock time?
    final open = await _readJson(session, 'unlocked');
    if (open == null || open['account'] != s.account.id) return;
    final last = DateTime.tryParse(open['lastUsed'] as String? ?? '');
    final minutes = settings.autoLockMinutes;
    if (minutes > 0 &&
        (last == null ||
            _clock().difference(last) > Duration(minutes: minutes))) {
      await session.write('unlocked', null);
      return;
    }
    try {
      await _open(
        await UnlockedKeys.fromUserKey(
          s.account,
          base64.decode(open['userKey']! as String),
        ),
      );
    } on Object {
      await session.write('unlocked', null);
    }
  }

  /// Checks an address like the apps: https, plain http only for local
  /// addresses.
  static Uri parseAddress(String address) {
    var text = address.trim();
    if (text.isEmpty) throw const ExtensionError('enterServerAddress');
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.host.isEmpty ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw const ExtensionError('invalidAddress');
    }
    if (uri.scheme == 'http' && !SixoraApi.isLocalHost(uri.host)) {
      throw const ExtensionError('httpOnlyLocal');
    }
    return SixoraApi.normalizeBaseUrl(uri);
  }

  Future<void> signIn(Uri server, String username, String password) async {
    final name = username.trim();
    if (name.isEmpty || password.isEmpty) {
      throw const ExtensionError('enterUsernameAndPassword');
    }
    final api = SixoraApi(server);
    try {
      final info = await api.info();
      final pre = await api.prelogin(name);
      final derived = await derivePasswordKeysAsync(
        password,
        pre.salt,
        KdfParams.fromJson(pre.kdf),
      );
      final r = await api.login(
        username: name,
        authKey: derived.authKeyB64,
        device: device,
      );
      final keys = await UnlockedKeys.unlock(r.account, derived.kek);
      final s = StoredAccount(
        server: api.baseUrl,
        serverName: info.name,
        account: r.account,
        encryptedToken: await StoredAccount.encryptToken(
          keys.userKey,
          r.account.id,
          r.token,
        ),
      )..apply(await api.sync(0));
      stored = s;
      signedOutRemotely = false;
      await _save();
      await _open(keys);
    } finally {
      api.close();
    }
  }

  Future<void> unlock(String password) async {
    final s = stored!;
    if (password.isEmpty) throw const ExtensionError('wrongPassword');
    final derived = await derivePasswordKeysAsync(
      password,
      s.account.salt,
      KdfParams.fromJson(s.account.kdf),
    );
    try {
      await _open(await UnlockedKeys.unlock(s.account, derived.kek));
    } on CryptoException {
      // A typo, or the password was changed in an app: then the server
      // has a new salt and this session has ended there anyway.
      final api = SixoraApi(s.server);
      try {
        final salt = (await api.prelogin(s.account.username)).salt;
        if (salt != s.account.salt) {
          await _forget();
          signedOutRemotely = true;
          throw const ExtensionError('passwordChanged');
        }
      } on ApiException {
        // Offline: cannot tell.
      } finally {
        api.close();
      }
      throw const ExtensionError('wrongPassword');
    }
  }

  /// Unlocks with the user key from the desktop app (see `AppUnlock`).
  Future<void> unlockWithUserKey(Uint8List userKey) async {
    final s = stored;
    if (s == null) throw const ExtensionError('app_failed');
    try {
      await _open(await UnlockedKeys.fromUserKey(s.account, userKey));
    } on CryptoException {
      throw const ExtensionError('app_failed');
    }
  }

  Future<void> _open(UnlockedKeys keys) async {
    _keys = keys;
    await _remember();
    await _decrypt();
    stage = Stage.unlocked;
  }

  Future<void> _remember() => session.write(
    'unlocked',
    jsonEncode({
      'account': stored!.account.id,
      'userKey': base64.encode(_keys!.userKey),
      'lastUsed': _clock().toIso8601String(),
    }),
  );

  /// The auto-lock counts from the last use.
  Future<void> touch() async {
    if (_keys != null) await _remember();
  }

  Future<void> _decrypt() async {
    final r = await decryptCodes(stored!, _keys!);
    codes = r.codes;
    passkeys = r.passkeys;
    unreadable = r.unreadable;
    await _writePasskeyIndex();
  }

  /// Salted hashes of the sites with a passkey (see [passkeyIndex]).
  static const passkeyIndexEntry = 'passkeyIndex';

  Future<void> _writePasskeyIndex() async {
    final old = await _readJson(local, passkeyIndexEntry);
    final salt =
        old?['salt'] as String? ?? base64.encode(VaultCrypto.randomBytes(16));
    await local.write(
      passkeyIndexEntry,
      passkeyIndex(passkeys.map((p) => p.passkey.rpId), salt),
    );
  }

  /// Passkeys [request] may use: for its site, and if the site names some,
  /// only those.
  List<StoredPasskey> passkeysFor(PasskeyRequest request) => [
    for (final p in passkeys)
      if (p.passkey.rpId == request.rpId &&
          (request.allow.isEmpty ||
              request.allow.contains(p.passkey.credentialId)))
        p,
  ];

  /// Makes a passkey for [request] and stores it in the personal vault
  /// (else the first one this account may write to). A site's passkey for
  /// the same user is replaced, as authenticators do. Answers for the page.
  Future<Map<String, Object?>> createPasskey(
    PasskeyRequest request, {
    required bool userVerified,
  }) async {
    final s = stored!;
    final keys = _keys!;
    if (passkeys.any((p) => request.exclude.contains(p.passkey.credentialId))) {
      throw const ExtensionError('passkey_exists');
    }
    final writable = s.vaults.values.where((v) => v.role.canWrite).toList()
      ..sort((a, b) => a.personal == b.personal ? 0 : (a.personal ? -1 : 1));
    if (writable.isEmpty) throw const ExtensionError('passkey_no_vault');
    final same = passkeys
        .where(
          (p) =>
              p.passkey.rpId == request.rpId &&
              p.passkey.userHandle == request.userHandle,
        )
        .firstOrNull;
    final vault = same == null
        ? writable.first
        : s.vaults[same.vaultId] ?? writable.first;
    final passkey = WebAuthn.create(
      rpId: request.rpId,
      rpName: request.rpName,
      userHandle: request.userHandle,
      userName: request.userName,
      displayName: request.displayName,
      now: _clock(),
    );
    final id = same?.id ?? VaultCrypto.newId();
    final data = await UnlockedKeys.encryptPasskey(
      await keys.openVaultKey(vault),
      vault.id,
      id,
      passkey,
    );
    final api = SixoraApi(s.server, token: await s.token(keys.userKey));
    try {
      await api.putEntry(
        id: id,
        vaultId: vault.id,
        data: data,
        baseRevision: same?.revision ?? 0,
        keyVersion: vault.keyVersion,
      );
    } on ApiException catch (e) {
      throw e.offline ? const ExtensionError('passkey_offline') : e;
    } finally {
      api.close();
    }
    final answer = request.created(passkey, userVerified: userVerified);
    await sync();
    return answer;
  }

  /// Fetches the changes since the last sync. Offline the list keeps the
  /// stored state ([syncError]).
  Future<void> sync() async {
    final s = stored;
    final keys = _keys;
    if (s == null || keys == null) return;
    final api = SixoraApi(s.server, token: await s.token(keys.userKey));
    try {
      s.apply(await api.sync(s.cursor));
      syncError = null;
      await _save();
      await _decrypt();
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await _forget();
        signedOutRemotely = true;
        return;
      }
      syncError = e;
    } finally {
      api.close();
    }
  }

  Future<void> lock() async {
    _wipe();
    await session.write('unlocked', null);
    if (stored != null) stage = Stage.locked;
  }

  /// Ends the session on the server (when unlocked) and forgets the
  /// account here.
  Future<void> signOut() async {
    final s = stored;
    final keys = _keys;
    if (s != null && keys != null) {
      final api = SixoraApi(s.server, token: await s.token(keys.userKey));
      try {
        await api.logout();
      } on ApiException {
        // The session expires on the server anyway.
      } finally {
        api.close();
      }
    }
    await _forget();
  }

  Future<void> saveSettings() =>
      local.write('settings', jsonEncode(settings.toJson()));

  Future<void> _save() => local.write('account', jsonEncode(stored!.toJson()));

  Future<void> _forget() async {
    _wipe();
    stored = null;
    syncError = null;
    await local.write('account', null);
    await local.write(passkeyIndexEntry, null);
    // A new account gets a new key, to be connected again.
    await local.write(linkKeyEntry, null);
    await session.write('unlocked', null);
    stage = Stage.setup;
  }

  void _wipe() {
    final keys = _keys;
    if (keys != null) {
      keys.userKey.fillRange(0, keys.userKey.length, 0);
      keys.privateKey.fillRange(0, keys.privateKey.length, 0);
    }
    _keys = null;
    codes = const [];
    passkeys = const [];
    unreadable = 0;
  }
}

/// The session's name on the server, e.g. "Firefox · macOS", so the apps
/// can show who signed in.
DeviceInfo browserDevice(String userAgent, {bool brave = false}) {
  final browser = switch (userAgent) {
    _ when brave => 'Brave',
    _ when userAgent.contains('Firefox/') => 'Firefox',
    _ when userAgent.contains('OPR/') || userAgent.contains('Opera') => 'Opera',
    _ when userAgent.contains('Edg/') => 'Edge',
    _ when userAgent.contains('Vivaldi') => 'Vivaldi',
    _ when userAgent.contains('Chrome/') => 'Chrome',
    _ when userAgent.contains('Safari/') => 'Safari',
    _ => 'Browser',
  };
  final os = switch (userAgent) {
    _ when userAgent.contains('iPhone') || userAgent.contains('iPad') => 'iOS',
    _ when userAgent.contains('Android') => 'Android',
    _ when userAgent.contains('Mac OS X') || userAgent.contains('Macintosh') =>
      'macOS',
    _ when userAgent.contains('Windows') => 'Windows',
    _ when userAgent.contains('CrOS') => 'ChromeOS',
    _ when userAgent.contains('Linux') => 'Linux',
    _ => '',
  };
  return DeviceInfo(
    name: os.isEmpty ? browser : '$browser · $os',
    platform: 'browser',
  );
}
