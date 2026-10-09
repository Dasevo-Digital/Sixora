import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sixora_core/sixora_core.dart';

import '../environment.dart';
import 'biometric_vault.dart';
import 'local_store.dart';
import 'secret_store.dart';

enum Phase { loading, setup, locked, unlocked }

/// A vault with its decrypted name and key.
class VaultView {
  VaultView(this.dto, this.name, this.key);
  final VaultDto dto;
  final String name;
  final Uint8List key;

  String get id => dto.id;
  bool get canWrite => dto.role.canWrite;
  bool get personal => dto.personal;
  bool get shared =>
      dto.memberCount > 1 || !dto.personal && dto.role != VaultRole.owner;
}

/// A decrypted entry.
class Item {
  Item(this.id, this.vaultId, this.revision, this.entry);
  final String id;
  final String vaultId;
  final int revision;
  final OtpEntry entry;
}

/// Error for the user, in German.
class UserError implements Exception {
  const UserError(this.message);
  final String message;
  @override
  String toString() => message;
}

String errorText(Object e) => switch (e) {
  UserError(:final message) => message,
  ApiException(:final message) => message,
  CryptoException(:final message) => message,
  FormatException(:final message) => message,
  _ => 'Unerwarteter Fehler: $e',
};

/// State of the whole app: account, lock, vaults, entries and sync.
class AppController extends ChangeNotifier {
  AppController._(this.store, this.secrets, this.settings, this.cached);

  final LocalStore store;
  final SecretStore secrets;
  final AppSettings settings;
  CachedAccount? cached;

  Phase phase = Phase.loading;
  SixoraApi? _api;
  UnlockedKeys? _keys;
  final Map<String, VaultView> _vaults = {};
  List<Item> items = const [];
  int undecryptable = 0;

  bool syncing = false;
  String? syncError;

  /// Shown once on the welcome screen, e.g. after a remote logout.
  String? notice;
  late final BiometricVault biometrics;

  /// Set after an unlock with the password when Face ID & co. could be
  /// offered; the home screen asks once.
  bool offerBiometrics = false;
  Timer? _syncTimer;

  static Future<AppController> create() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, AppEnv.dataFolder))
      ..createSync(recursive: true);
    final store = LocalStore(dir);
    final secrets = await SecretStore.open(dir);
    final c = AppController._(
      store,
      secrets,
      store.loadSettings(),
      store.loadAccount(),
    );
    c.phase = c.cached == null ? Phase.setup : Phase.locked;
    if (c.cached != null) c._api = c._newApi(c.cached!.server);
    c.biometrics = await BiometricVault.open(secrets);
    // Up to 0.1.3 the key sat in the normal keystore entry also on iOS and
    // Android; there it now has to be bound to biometrics, so set it up anew.
    if (BiometricVault.hardwareBound && secrets['quickKey'] != null) {
      await secrets.set('quickKey', null);
      c.settings.quickUnlock = false;
      c.settings.biometricsOffered = false;
      await store.saveSettings(c.settings);
    }
    if (!c.biometrics.available && c.settings.quickUnlock) {
      c.settings.quickUnlock = false;
    }
    return c;
  }

  SixoraApi _newApi(Uri server) => SixoraApi(server, token: secrets['token']);

  AccountBundle? get account => cached?.account;
  List<VaultView> get vaults => _vaults.values.toList();
  VaultView? vault(String id) => _vaults[id];
  List<VaultView> get writableVaults =>
      _vaults.values.where((v) => v.canWrite).toList();
  bool get isAdmin => account?.isAdmin ?? false;
  bool get biometricsAvailable => biometrics.available;

  /// "Face ID", "Touch ID", "Fingerabdruck", "Windows Hello" …
  String get biometricLabel => biometrics.kind ?? 'Biometrie';
  bool get quickUnlockReady => settings.quickUnlock && biometrics.available;

  void _offerBiometrics() {
    offerBiometrics =
        biometrics.available &&
        !settings.quickUnlock &&
        !settings.biometricsOffered;
  }

  List<String> get groups {
    final set = <String>{
      for (final i in items)
        if (i.entry.group.isNotEmpty) i.entry.group,
    };
    return set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> saveSettings() async {
    await store.saveSettings(settings);
    notifyListeners();
  }

  static Future<DeviceInfo> deviceInfo() async {
    var name = '';
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        name = '${a.manufacturer} ${a.model}';
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        name = i.name.isNotEmpty ? i.name : i.model;
      } else {
        name = Platform.localHostname;
      }
    } on Object {
      name = Platform.localHostname;
    }
    return DeviceInfo(name: name.trim(), platform: Platform.operatingSystem);
  }

  // --- Setup -----------------------------------------------------------------

  /// Checks a server address and returns its info. Plain HTTP is only
  /// accepted for local addresses.
  static Future<(Uri, ServerInfo)> probe(String address) async {
    var text = address.trim();
    if (text.isEmpty) {
      throw const UserError('Bitte die Server-Adresse eingeben');
    }
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.host.isEmpty ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw const UserError('Ungültige Adresse');
    }
    if (uri.scheme == 'http' && !SixoraApi.isLocalHost(uri.host)) {
      throw const UserError(
        'Unverschlüsseltes HTTP ist nur im lokalen Netz erlaubt. '
        'Bitte https:// verwenden.',
      );
    }
    final api = SixoraApi(uri);
    try {
      return (api.baseUrl, await api.info());
    } finally {
      api.close();
    }
  }

  /// Creates an account and unlocks it. Returns the recovery key, which the
  /// user has to write down now.
  Future<String> register({
    required Uri server,
    required String serverName,
    required String username,
    required String password,
    String? inviteCode,
  }) async {
    final created = await NewAccount.create(
      username: username,
      password: password,
    );
    final api = SixoraApi(server);
    final result = await api.register({
      ...created.body,
      'device': (await deviceInfo()).toJson(),
      if (inviteCode != null && inviteCode.trim().isNotEmpty)
        'inviteCode': inviteCode.trim(),
    });
    await _adopt(api, result, serverName);
    _keys = await UnlockedKeys.unlock(result.account, created.kek);
    // [enter] follows once the user has stored the recovery key.
    return created.recoveryKey;
  }

  Future<void> login({
    required Uri server,
    required String serverName,
    required String username,
    required String password,
  }) async {
    final api = SixoraApi(server);
    final pre = await api.prelogin(username.trim());
    final keys = await derivePasswordKeysAsync(
      password,
      pre.salt,
      KdfParams.fromJson(pre.kdf),
    );
    final result = await api.login(
      username: username.trim(),
      authKey: keys.authKeyB64,
      device: await deviceInfo(),
    );
    await _adopt(api, result, serverName);
    _keys = await UnlockedKeys.unlock(result.account, keys.kek);
    _offerBiometrics();
    await _afterUnlock();
  }

  /// Sets a new password with the recovery key. Returns the new recovery
  /// key (the old one is used up).
  Future<String> recover({
    required Uri server,
    required String serverName,
    required String username,
    required String recoveryKey,
    required String newPassword,
  }) async {
    final api = SixoraApi(server);
    final recovery = VaultCrypto.recoveryKeys(recoveryKey);
    final start = await api.recoverStart(
      username: username.trim(),
      recoveryAuth: recovery.auth,
    );
    final Uint8List userKey;
    try {
      userKey = await VaultCrypto.decrypt(
        recovery.kek,
        start.recoveryWrappedUserKey,
        aad: 'sixora-user-key|${start.userId}',
      );
    } on CryptoException {
      throw const UserError('Wiederherstellungsschlüssel passt nicht');
    }
    final fresh = await newRecoveryFor(userId: start.userId, userKey: userKey);
    final result = await api.recoverFinish({
      'username': username.trim(),
      'recoveryAuth': recovery.auth,
      ...await rewrapForNewPassword(
        userId: start.userId,
        userKey: userKey,
        newPassword: newPassword,
      ),
      'newRecoveryWrappedUserKey': fresh.wrapped,
      'newRecoveryAuth': fresh.auth,
      'device': (await deviceInfo()).toJson(),
    });
    await _adopt(api, result, serverName);
    await _forgetBiometrics();
    _keys = await UnlockedKeys.fromUserKey(result.account, userKey);
    // [enter] follows once the user has stored the new recovery key.
    return fresh.recoveryKey;
  }

  Future<void> _adopt(
    SixoraApi api,
    LoginResult result,
    String serverName,
  ) async {
    final previous = cached;
    final sameAccount =
        previous != null &&
        previous.account.id == result.account.id &&
        previous.server == api.baseUrl;
    cached = sameAccount
        ? (previous
            ..account = result.account
            ..serverName = serverName)
        : CachedAccount(
            server: api.baseUrl,
            serverName: serverName,
            account: result.account,
          );
    if (!sameAccount) await _forgetBiometrics();
    await secrets.set('token', result.token);
    _api?.close();
    _api = api;
    await store.saveAccount(cached!);
  }

  // --- Lock ------------------------------------------------------------------

  Future<void> unlockWithPassword(String password) async {
    final c = cached!;
    final kdf = KdfParams.fromJson(c.account.kdf);
    final keys = await derivePasswordKeysAsync(password, c.account.salt, kdf);
    try {
      _keys = await UnlockedKeys.unlock(c.account, keys.kek);
    } on CryptoException {
      // Either a typo, or the password was changed on another device: then
      // the server has a new salt, this device was logged out there, and
      // logging in fetches the new keys. Typos never reach the login.
      String? salt;
      try {
        salt = (await _api!.prelogin(c.account.username)).salt;
      } on ApiException {
        salt = null;
      }
      if (salt == null || salt == c.account.salt) {
        throw const UserError('Master-Passwort ist falsch');
      }
      await login(
        server: c.server,
        serverName: c.serverName,
        username: c.account.username,
        password: password,
      );
      return;
    }
    if (secrets['token'] == null) {
      // No session (e.g. Linux without keystore after a logout): log in
      // with the auth key derived just now.
      try {
        final result = await _api!.login(
          username: c.account.username,
          authKey: keys.authKeyB64,
          device: await deviceInfo(),
        );
        await secrets.set('token', result.token);
      } on ApiException {
        // Offline: codes work anyway, sync later.
      }
    }
    _offerBiometrics();
    await _afterUnlock();
  }

  /// Null when unlocked; otherwise why not ([BiometricResult.cancelled] or
  /// [BiometricResult.password]), so the lock screen can turn to the master
  /// password.
  Future<BiometricResult?> unlockWithBiometrics() async {
    final (result, userKey) = await biometrics.unlock();
    switch (result) {
      case BiometricResult.cancelled || BiometricResult.password:
        return result;
      case BiometricResult.invalidated:
        await _forgetBiometrics();
        throw UserError(
          'Entsperren mit $biometricLabel ist nicht mehr gültig, z. B. weil '
          'ein Finger oder Gesicht neu registriert wurde. Bitte mit dem '
          'Master-Passwort entsperren und es danach neu einrichten.',
        );
      case BiometricResult.unlocked:
        break;
    }
    try {
      _keys = await UnlockedKeys.fromUserKey(cached!.account, userKey!);
    } on CryptoException {
      await _forgetBiometrics();
      throw UserError(
        'Entsperren mit $biometricLabel ist nicht mehr gültig. Bitte mit dem '
        'Master-Passwort entsperren.',
      );
    }
    await _afterUnlock();
    return null;
  }

  /// Turns unlocking with biometrics on or off; false if the user did not
  /// confirm.
  Future<bool> setQuickUnlock(bool enabled) async {
    settings.biometricsOffered = true;
    if (enabled) {
      final bool ok;
      try {
        ok = await biometrics.enable(_keys!.userKey);
      } on PlatformException catch (e) {
        await biometrics.disable();
        await saveSettings();
        throw UserError(
          '$biometricLabel ließ sich nicht einrichten: ${e.message ?? e.code}',
        );
      }
      if (!ok) {
        await biometrics.disable();
        await saveSettings();
        return false;
      }
    } else {
      await biometrics.disable();
    }
    settings.quickUnlock = enabled;
    await saveSettings();
    return true;
  }

  Future<void> _forgetBiometrics() async {
    await biometrics.disable();
    settings.quickUnlock = false;
    await store.saveSettings(settings);
  }

  /// Opens the vault after registration or recovery.
  Future<void> enter() {
    _offerBiometrics();
    return _afterUnlock();
  }

  Future<void> _afterUnlock() async {
    await _decryptAll();
    phase = Phase.unlocked;
    notifyListeners();
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) => sync());
    unawaited(sync());
  }

  void lock() {
    if (phase != Phase.unlocked) return;
    _syncTimer?.cancel();
    _wipeKeys();
    items = const [];
    phase = Phase.locked;
    notifyListeners();
  }

  void _wipeKeys() {
    final keys = _keys;
    if (keys != null) {
      keys.userKey.fillRange(0, keys.userKey.length, 0);
      keys.privateKey.fillRange(0, keys.privateKey.length, 0);
    }
    for (final v in _vaults.values) {
      v.key.fillRange(0, v.key.length, 0);
    }
    _vaults.clear();
    _keys = null;
  }

  /// Logs out this device and removes all local data.
  Future<void> logout({String? notice}) async {
    _syncTimer?.cancel();
    final api = _api;
    if (api != null && notice == null) {
      try {
        await api.logout();
      } on ApiException {
        // The session expires on the server anyway.
      }
    }
    api?.close();
    _api = null;
    _wipeKeys();
    items = const [];
    cached = null;
    await store.deleteAccount();
    await biometrics.disable();
    await secrets.clear();
    settings.quickUnlock = false;
    settings.biometricsOffered = false;
    await store.saveSettings(settings);
    this.notice = notice;
    phase = Phase.setup;
    notifyListeners();
  }

  // --- Sync ------------------------------------------------------------------

  /// Runs [action] against the server and turns a revoked session into a
  /// local logout.
  Future<T> _online<T>(Future<T> Function(SixoraApi api) action) async {
    final api = _api;
    if (api == null || api.token == null) {
      throw const UserError(
        'Keine Sitzung. Bitte sperren und mit Passwort entsperren.',
      );
    }
    try {
      return await action(api);
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await logout(
          notice: e.code == 'disabled'
              ? 'Dein Konto wurde gesperrt.'
              : 'Dieses Gerät wurde abgemeldet (Passwort geändert oder Gerät entfernt). '
                    'Bitte erneut anmelden.',
        );
        throw const UserError('Abgemeldet');
      }
      if (e.offline) {
        throw UserError('Keine Verbindung zum Server. ${e.message}.');
      }
      rethrow;
    }
  }

  Future<void> sync() async {
    if (phase != Phase.unlocked || syncing || _api?.token == null) return;
    syncing = true;
    notifyListeners();
    try {
      final result = await _online((api) => api.sync(cached!.cursor));
      await _applySync(result);
      syncError = null;
    } on UserError catch (e) {
      syncError = e.message;
    } on Object catch (e) {
      syncError = errorText(e);
    } finally {
      syncing = false;
      if (phase == Phase.unlocked) notifyListeners();
    }
  }

  Future<void> _applySync(SyncResult r) async {
    final c = cached;
    if (c == null) return;
    final ids = {for (final v in r.vaults) v.id};
    c.vaults
      ..clear()
      ..addAll({for (final v in r.vaults) v.id: v});
    c.entries.removeWhere(
      (_, e) => !ids.contains(e.vaultId) || r.resetVaults.contains(e.vaultId),
    );
    for (final e in r.entries) {
      if (e.deleted) {
        c.entries.remove(e.id);
      } else {
        c.entries[e.id] = e;
      }
    }
    c.cursor = r.cursor;
    c.lastSync = DateTime.now();
    await store.saveAccount(c);
    if (phase == Phase.unlocked) await _decryptAll();
  }

  Future<void> _decryptAll() async {
    final c = cached!;
    final keys = _keys!;
    for (final id in _vaults.keys.toList()) {
      if (c.vaults[id]?.sealedKey != _vaults[id]!.dto.sealedKey) {
        _vaults.remove(id);
      }
    }
    for (final dto in c.vaults.values) {
      try {
        final key = _vaults[dto.id]?.key ?? await keys.openVaultKey(dto);
        final name = await UnlockedKeys.decryptVaultName(
          key,
          dto.id,
          dto.encryptedName,
        );
        _vaults[dto.id] = VaultView(dto, name, key);
      } on CryptoException {
        _vaults.remove(dto.id);
      }
    }
    final list = <Item>[];
    var broken = 0;
    for (final e in c.entries.values) {
      final vault = _vaults[e.vaultId];
      if (vault == null) {
        broken++;
        continue;
      }
      try {
        list.add(
          Item(
            e.id,
            e.vaultId,
            e.revision,
            await UnlockedKeys.decryptEntry(vault.key, e.vaultId, e.id, e.data),
          ),
        );
      } on Object {
        broken++;
      }
    }
    list.sort(_compare);
    items = list;
    undecryptable = broken;
  }

  static int _compare(Item a, Item b) {
    if (a.entry.favorite != b.entry.favorite) return a.entry.favorite ? -1 : 1;
    final byName = a.entry.displayName.toLowerCase().compareTo(
      b.entry.displayName.toLowerCase(),
    );
    return byName != 0 ? byName : a.entry.account.compareTo(b.entry.account);
  }

  // --- Entries ---------------------------------------------------------------

  Future<void> _storeEntry(EntryDto dto) async {
    final c = cached!;
    if (dto.deleted) {
      c.entries.remove(dto.id);
    } else {
      c.entries[dto.id] = dto;
    }
    await store.saveAccount(c);
    await _decryptAll();
    notifyListeners();
  }

  Future<T> _write<T>(Future<T> Function(SixoraApi api) action) async {
    try {
      return await _online(action);
    } on ApiException catch (e) {
      if (e.conflict) {
        await sync();
        throw const UserError(
          'Der Eintrag wurde inzwischen auf einem anderen Gerät geändert. '
          'Die aktuelle Fassung ist geladen, bitte erneut versuchen.',
        );
      }
      rethrow;
    }
  }

  /// Creates ([item] null) or updates an entry.
  Future<void> saveEntry(
    OtpEntry entry, {
    required String vaultId,
    Item? item,
  }) async {
    entry.validate();
    if (item != null && item.vaultId != vaultId) {
      await moveEntry(item, vaultId, entry: entry);
      return;
    }
    final vault = _vaults[vaultId];
    if (vault == null || !vault.canWrite) {
      throw const UserError('In diesen Tresor darfst du nicht schreiben');
    }
    final id = item?.id ?? VaultCrypto.newId();
    final data = await UnlockedKeys.encryptEntry(vault.key, vaultId, id, entry);
    final dto = await _write(
      (api) => api.putEntry(
        id: id,
        vaultId: vaultId,
        data: data,
        baseRevision: item?.revision ?? 0,
      ),
    );
    await _storeEntry(dto);
  }

  /// Moving means: create in the target, then delete in the source (the
  /// ciphertext is bound to its vault).
  Future<void> moveEntry(
    Item item,
    String targetVaultId, {
    OtpEntry? entry,
  }) async {
    await saveEntry(entry ?? item.entry, vaultId: targetVaultId);
    await deleteEntry(item);
  }

  Future<void> deleteEntry(Item item) async {
    final dto = await _write(
      (api) => api.deleteEntry(item.id, baseRevision: item.revision),
    );
    await _storeEntry(dto);
  }

  /// HOTP: the shown code is used up, so the counter moves on.
  Future<void> nextHotp(Item item) => saveEntry(
    item.entry.copyWith(counter: item.entry.counter + 1),
    vaultId: item.vaultId,
    item: item,
  );

  Future<void> toggleFavorite(Item item) => saveEntry(
    item.entry.copyWith(favorite: !item.entry.favorite),
    vaultId: item.vaultId,
    item: item,
  );

  /// Imports entries one by one; returns how many were added.
  Future<int> importEntries(
    List<OtpEntry> entries, {
    required String vaultId,
    void Function(int done)? progress,
  }) async {
    var done = 0;
    for (final e in entries) {
      await saveEntry(e, vaultId: vaultId);
      progress?.call(++done);
    }
    return done;
  }

  bool isDuplicate(OtpEntry e) => items.any((i) => i.entry.sameKeyAs(e));

  // --- Vaults ----------------------------------------------------------------

  Future<void> createVault(String name) async {
    final id = VaultCrypto.newId();
    final key = VaultCrypto.randomBytes(32);
    await _online(
      (api) async => api.createVault(
        id: id,
        encryptedName: await UnlockedKeys.encryptVaultName(
          key,
          id,
          name.trim(),
        ),
        sealedKey: await VaultCrypto.seal(key, _keys!.publicKey),
      ),
    );
    await sync();
  }

  Future<void> renameVault(VaultView vault, String name) async {
    final encrypted = await UnlockedKeys.encryptVaultName(
      vault.key,
      vault.id,
      name.trim(),
    );
    await _online((api) => api.renameVault(vault.id, encrypted));
    await sync();
  }

  Future<void> deleteVault(VaultView vault) async {
    await _online((api) => api.deleteVault(vault.id));
    await sync();
  }

  Future<List<MemberDto>> members(String vaultId) =>
      _online((api) => api.members(vaultId));

  Future<UserDto> lookupUser(String username) =>
      _online((api) => api.lookupUser(username.trim()));

  String get myFingerprint => VaultCrypto.fingerprint(account!.publicKey);

  Future<void> share(VaultView vault, UserDto user, VaultRole role) async {
    final sealed = await VaultCrypto.seal(vault.key, user.publicKey);
    await _online(
      (api) => api.addMember(
        vault.id,
        userId: user.id,
        sealedKey: sealed,
        role: role,
      ),
    );
    await sync();
  }

  Future<void> removeMember(VaultView vault, String userId) async {
    await _online((api) => api.removeMember(vault.id, userId));
    await sync();
  }

  // --- Account ---------------------------------------------------------------

  SixoraApi get api => _api!;

  Future<T> online<T>(Future<T> Function(SixoraApi api) action) =>
      _online(action);

  Future<String> _currentAuthKey(String password) async {
    final a = account!;
    final keys = await derivePasswordKeysAsync(
      password,
      a.salt,
      KdfParams.fromJson(a.kdf),
    );
    try {
      await UnlockedKeys.unlock(a, keys.kek);
    } on CryptoException {
      throw const UserError('Aktuelles Master-Passwort ist falsch');
    }
    return keys.authKeyB64;
  }

  Future<void> changePassword(String current, String next) async {
    final authKey = await _currentAuthKey(current);
    final body = await rewrapForNewPassword(
      userId: account!.id,
      userKey: _keys!.userKey,
      newPassword: next,
    );
    await _online((api) => api.changePassword({'authKey': authKey, ...body}));
    final fresh = await _online((api) => api.account());
    cached!.account = fresh;
    await store.saveAccount(cached!);
  }

  Future<String> renewRecoveryKey(String password) async {
    final authKey = await _currentAuthKey(password);
    final r = await newRecoveryFor(
      userId: account!.id,
      userKey: _keys!.userKey,
    );
    await _online(
      (api) => api.setRecoveryKey(
        authKey: authKey,
        recoveryWrappedUserKey: r.wrapped,
        recoveryAuth: r.auth,
      ),
    );
    return r.recoveryKey;
  }

  Future<void> deleteAccount(String password) async {
    final authKey = await _currentAuthKey(password);
    await _online((api) => api.deleteAccount(authKey));
    await logout(notice: 'Dein Konto wurde gelöscht.');
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _api?.close();
    super.dispose();
  }
}
