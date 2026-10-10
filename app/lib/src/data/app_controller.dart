import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sixora_core/sixora_core.dart';

import '../environment.dart';
import '../l10n.dart';
import '../platform/backup_folder.dart';
import 'biometric_vault.dart';
import 'error_texts.dart';
import 'local_server.dart';
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

/// What reading the newest backup back found.
class BackupVerification {
  const BackupVerification({
    required this.file,
    required this.files,
    required this.accounts,
    required this.missing,
  });
  final String file;

  /// Backup files in the folder.
  final int files;
  final int accounts;

  /// Accounts here that the backup does not contain (added since).
  final List<String> missing;
}

/// A deleted entry in the recycle bin.
class TrashItem {
  TrashItem(this.item, this.deletedAt);
  final Item item;
  final DateTime? deletedAt;
}

/// Error for the user, in German.
class UserError implements Exception {
  const UserError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A check that protects the vaults failed; shown prominently.
class SecurityError extends UserError {
  const SecurityError(super.message);
}

/// The move to a server stopped half way; [AppController.finishMove] goes
/// on. Carries the recovery key of the account just created there, which
/// the user has to see anyway.
class MoveIncomplete extends UserError {
  const MoveIncomplete(super.message, this.recoveryKey);
  final String? recoveryKey;
}

String errorText(Object e) => switch (e) {
  UserError(:final message) => message,
  ApiException() => apiErrorText(e),
  CryptoException(:final message) => coreErrorText(message),
  FormatException(:final message) => coreErrorText(message),
  _ => t.unexpectedError(e),
};

/// State of the whole app: account, lock, vaults, entries and sync.
class AppController extends ChangeNotifier {
  AppController._(
    this.store,
    this.secrets,
    this.settings,
    this.cached, {
    this.passive = false,
  });

  final LocalStore store;
  final SecretStore secrets;
  final AppSettings settings;
  CachedAccount? cached;

  /// Only reads: no sync, no backup, no server. For the autofill window,
  /// which runs beside the app and must not write the same files.
  final bool passive;

  Phase phase = Phase.loading;
  SixoraApi? _api;
  UnlockedKeys? _keys;
  final Map<String, VaultView> _vaults = {};
  List<Item> items = const [];
  int undecryptable = 0;

  bool syncing = false;
  String? syncError;

  /// Something that needs the user's attention for security reasons, e.g.
  /// a member's key that suddenly differs.
  String? securityWarning;

  /// Shown once on the welcome screen, e.g. after a remote logout.
  String? notice;
  late final BiometricVault biometrics;

  /// Set after an unlock with the password when Face ID & co. could be
  /// offered; the home screen asks once.
  bool offerBiometrics = false;

  /// Generation of the long-poll loop; a new one stops the old.
  int _watch = 0;
  bool _rotating = false;
  Timer? _backupTimer;

  /// Vaults whose rotation failed since the last unlock: not retried with
  /// every sync.
  final _rotationFailed = <String>{};
  Future<void> _applying = Future.value();

  /// For widget tests: data in [dir], no keystore, no server.
  @visibleForTesting
  factory AppController.forTest(Directory dir) {
    final store = LocalStore(dir);
    final secrets = SecretStore.inFolder(dir);
    LocalServer.folder = Directory(p.join(dir.path, 'local'));
    return AppController._(store, secrets, store.loadSettings(), null)
      ..phase = Phase.setup
      ..biometrics = BiometricVault.none(secrets);
  }

  static Future<AppController> create({bool passive = false}) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, AppEnv.dataFolder))
      ..createSync(recursive: true);
    final store = LocalStore(dir);
    final secrets = await SecretStore.open(dir);
    LocalServer.folder = Directory(p.join(dir.path, 'local'));
    final c = AppController._(
      store,
      secrets,
      store.loadSettings(),
      store.loadAccount(),
      passive: passive,
    );
    c.phase = c.cached == null ? Phase.setup : Phase.locked;
    if (c.cached != null && !passive) c._api = c._newApi(c.cached!.server);
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

  SixoraApi _newApi(Uri server) => apiFor(server, token: secrets['token']);

  /// A client for [server]; the local mode answers in the app itself.
  static SixoraApi apiFor(Uri server, {String? token}) =>
      LocalServer.isLocal(server)
      ? LocalServer.api(token: token)
      : SixoraApi(server, token: token);

  AccountBundle? get account => cached?.account;
  List<VaultView> get vaults => _vaults.values.toList();
  VaultView? vault(String id) => _vaults[id];
  List<VaultView> get writableVaults =>
      _vaults.values.where((v) => v.canWrite).toList();
  bool get isAdmin => account?.isAdmin ?? false;
  bool get biometricsAvailable => biometrics.available;

  /// "Face ID", "Touch ID", "Fingerabdruck", "Windows Hello" …
  String get biometricLabel => biometrics.kind ?? t.biometrics;
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
      throw UserError(t.enterServerAddress);
    }
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.host.isEmpty ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw UserError(t.invalidAddress);
    }
    if (uri.scheme == 'http' && !SixoraApi.isLocalHost(uri.host)) {
      throw UserError(t.httpOnlyLocal);
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
    final api = apiFor(server);
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
    final api = apiFor(server);
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
    final api = apiFor(server);
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
      throw UserError(t.recoveryKeyMismatch);
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
      if (passive) throw UserError(t.masterPasswordWrong);
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
        throw UserError(t.masterPasswordWrong);
      }
      await login(
        server: c.server,
        serverName: c.serverName,
        username: c.account.username,
        password: password,
      );
      return;
    }
    if (secrets['token'] == null && !passive) {
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
        throw UserError(t.biometricsInvalidatedEnrolled(biometricLabel));
      case BiometricResult.unlocked:
        break;
    }
    try {
      _keys = await UnlockedKeys.fromUserKey(cached!.account, userKey!);
    } on CryptoException {
      await _forgetBiometrics();
      throw UserError(t.biometricsInvalidated(biometricLabel));
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
          t.biometricsSetupFailed(biometricLabel, e.message ?? e.code),
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
    if (passive) return;
    unawaited(sync());
    _startWatching();
    _scheduleBackup();
  }

  /// Keeps one request waiting at the server: changes from other devices
  /// arrive within a moment instead of with the next poll.
  void _startWatching() {
    final generation = ++_watch;
    // Without a server no other device changes anything.
    if (isLocal) return;
    unawaited(_watchLoop(generation));
  }

  void _stopWatching() => _watch++;

  /// App in the background: no open connection; back in front: catch up.
  void pauseSync() => _stopWatching();

  void resumeSync() {
    if (phase != Phase.unlocked) return;
    unawaited(sync());
    _startWatching();
  }

  Future<void> _watchLoop(int generation) async {
    var backoff = const Duration(seconds: 5);
    bool current() => generation == _watch && phase == Phase.unlocked;
    while (current()) {
      final since = cached?.cursor ?? 0;
      final started = DateTime.now();
      try {
        final result = await _online(
          (api) => api.sync(since, wait: const Duration(seconds: 25)),
        );
        if (!current()) return;
        await _apply(result);
        if (!current()) return;
        syncError = null;
        notifyListeners();
        backoff = const Duration(seconds: 5);
        // A server without long poll answers at once: then poll gently.
        if (result.cursor == since &&
            DateTime.now().difference(started) < const Duration(seconds: 2)) {
          await Future<void>.delayed(const Duration(seconds: 30));
        }
      } on Object catch (e) {
        if (!current()) return;
        syncError = errorText(e);
        notifyListeners();
        await Future<void>.delayed(backoff);
        backoff = backoff * 2 > const Duration(minutes: 1)
            ? const Duration(minutes: 1)
            : backoff * 2;
      }
    }
  }

  /// Applies sync results one after another.
  Future<void> _apply(SyncResult result) =>
      _applying = _applying.then((_) => _applySync(result));

  void lock() {
    if (phase != Phase.unlocked) return;
    _stopWatching();
    _moving = null;
    _rotationFailed.clear();
    _backupTimer?.cancel();
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
    _stopWatching();
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
    _moving = null;
    _backupTimer?.cancel();
    cached = null;
    this.notice = notice;
    phase = Phase.setup;
    // Closes the open pages at once: a sync still under way must not
    // redraw them without an account.
    notifyListeners();
    await store.deleteAccount();
    await biometrics.disable();
    await secrets.clear();
    settings.quickUnlock = false;
    settings.biometricsOffered = false;
    // The key belongs to this account; the folder may stay.
    settings.backupKey = null;
    await store.saveSettings(settings);
    notifyListeners();
  }

  // --- Sync ------------------------------------------------------------------

  /// Runs [action] against the server and turns a revoked session into a
  /// local logout.
  Future<T> _online<T>(Future<T> Function(SixoraApi api) action) async {
    final api = _api;
    if (api == null || api.token == null) {
      throw UserError(t.noSession);
    }
    try {
      return await action(api);
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await logout(
          notice: e.code == 'disabled'
              ? t.accountDisabledNotice
              : t.deviceSignedOutNotice,
        );
        throw UserError(t.signedOut);
      }
      if (e.offline) {
        throw UserError(t.noServerConnection(apiErrorText(e)));
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
      await _apply(result);
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
    // An answer older than what is stored (a long poll that overlapped a
    // manual sync) would bring back outdated entries.
    if (c == null || r.cursor < c.cursor) return;
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
    final sessions = r.sessions;
    if (sessions != null) {
      c.sessions = sessions;
      final ids = {for (final s in sessions) s.id};
      // The first time, everything already there counts as known.
      c.knownSessions = c.knownSessions == null
          ? ids
          : c.knownSessions!.intersection(ids);
    }
    await store.saveAccount(c);
    if (phase == Phase.unlocked) {
      await _decryptAll();
      _scheduleBackup();
      if (r.vaults.any((v) => v.rotationPending && v.role == VaultRole.owner)) {
        unawaited(Future(_rotatePending));
      }
    }
  }

  // --- Automatic backup -----------------------------------------------------

  static final _backupName = RegExp(
    r'^Sixora-Sicherung-\d{4}-\d{2}-\d{2}\.json$',
  );

  bool get autoBackup =>
      settings.backupFolder != null && settings.backupKey != null;

  String _backupAad(String accountId) => 'sixora-backup-key|$accountId';

  /// Backs up to [folder] from now on, encrypted with [password].
  Future<void> enableAutoBackup(FolderRef folder, String password) async {
    final key = await BackupKey.derive(password);
    settings
      ..backupFolder = folder.ref
      ..backupFolderLabel = folder.label;
    await _storeBackupKey(key);
    await backupNow();
  }

  /// Keeps the key of the backup password, wrapped with the user key.
  Future<void> _storeBackupKey(BackupKey key) async {
    final id = account!.id;
    settings
      ..backupKey = {
        'account': id,
        'kdf': key.kdf.toJson(),
        'salt': key.salt,
        'key': await VaultCrypto.encrypt(
          _keys!.userKey,
          key.key,
          aad: _backupAad(id),
        ),
      }
      ..lastBackupCursor = -1
      ..backupError = null;
    await saveSettings();
  }

  Future<void> disableAutoBackup() async {
    _backupTimer?.cancel();
    settings
      ..backupFolder = null
      ..backupFolderLabel = ''
      ..backupKey = null
      ..backupError = null;
    await saveSettings();
    notifyListeners();
  }

  /// After changes: one backup a little later, not one per keystroke.
  void _scheduleBackup() {
    if (!autoBackup || phase != Phase.unlocked) return;
    if (settings.lastBackupCursor == cached?.cursor) return;
    _backupTimer?.cancel();
    _backupTimer = Timer(const Duration(seconds: 15), () async {
      try {
        await backupNow();
      } on Object catch (e) {
        debugPrint('Automatische Sicherung fehlgeschlagen: $e');
      }
    });
  }

  /// Writes today's file (replacing an earlier one of the same day) and
  /// keeps the newest [AppSettings.backupKeep] files.
  Future<void> backupNow() async {
    final folder = settings.backupFolder;
    final c = cached;
    if (folder == null || c == null || _keys == null) return;
    try {
      final key = await _backupKey();
      if (key == null) return;
      final cursor = c.cursor;
      final entries = [for (final i in items) i.entry];
      final text = await SixoraBackup.encryptWithKey(entries, key);
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final name =
          'Sixora-Sicherung-${now.year}-${two(now.month)}-${two(now.day)}.json';
      await BackupFolder.write(folder, name, text);
      // Read it back: a file that cannot be opened is no backup.
      final back = await SixoraBackup.decryptWithKey(
        await BackupFolder.read(folder, name),
        key,
      );
      if (back.length != entries.length) {
        throw UserError(t.backupWrittenMismatch(back.length, entries.length));
      }
      final names = [
        for (final n in await BackupFolder.list(folder))
          if (_backupName.hasMatch(n)) n,
      ]..sort();
      for (final old in names.take(
        (names.length - settings.backupKeep).clamp(0, names.length),
      )) {
        await BackupFolder.delete(folder, old);
      }
      settings
        ..lastBackup = now
        ..lastBackupCursor = cursor
        ..backupError = null;
    } on PlatformException catch (e) {
      settings.backupError = e.message ?? e.code;
      throw UserError(t.backupFailed(settings.backupError!));
    } on Object catch (e) {
      settings.backupError = errorText(e);
      rethrow;
    } finally {
      await saveSettings();
      notifyListeners();
    }
  }

  /// The stored key of the backup password, opened with the user key.
  Future<BackupKey?> _backupKey() async {
    final stored = settings.backupKey;
    final keys = _keys;
    final c = cached;
    if (stored == null || keys == null || c == null) return null;
    if (stored['account'] != c.account.id) {
      throw UserError(t.backupOtherAccount);
    }
    return BackupKey(
      kdf: KdfParams.fromJson((stored['kdf']! as Map).cast()),
      salt: stored['salt']! as String,
      key: await VaultCrypto.decrypt(
        keys.userKey,
        stored['key']! as String,
        aad: _backupAad(c.account.id),
      ),
    );
  }

  /// Opens the newest backup in the folder like a restore would: decrypts
  /// it and compares it with the accounts here.
  Future<BackupVerification> verifyBackup() async {
    final folder = settings.backupFolder;
    final key = await _backupKey();
    if (folder == null || key == null) {
      throw UserError(t.backupNotSetUp);
    }
    try {
      final names = [
        for (final n in await BackupFolder.list(folder))
          if (_backupName.hasMatch(n)) n,
      ]..sort();
      if (names.isEmpty) {
        throw UserError(t.noBackupInFolder);
      }
      final entries = await SixoraBackup.decryptWithKey(
        await BackupFolder.read(folder, names.last),
        key,
      );
      final missing = [
        for (final i in items)
          if (!entries.any((e) => e.sameKeyAs(i.entry))) i.entry.displayName,
      ];
      return BackupVerification(
        file: names.last,
        files: names.length,
        accounts: entries.length,
        missing: missing,
      );
    } on PlatformException catch (e) {
      throw UserError(t.backupUnreadable(e.message ?? e.code));
    }
  }

  // --- Sign-ins ------------------------------------------------------------

  /// Sign-ins of other devices this device has not seen before: somebody
  /// with the master password – or the user on a new device.
  List<SessionDto> get unknownSessions {
    final c = cached;
    final known = c?.knownSessions;
    if (c == null || known == null) return const [];
    return [
      for (final s in c.sessions)
        if (!s.current && !known.contains(s.id)) s,
    ];
  }

  Future<void> acknowledgeSession(String id) async {
    final c = cached!;
    (c.knownSessions ??= {}).add(id);
    await store.saveAccount(c);
    notifyListeners();
  }

  /// Signs the unknown device out.
  Future<void> revokeSession(String id) async {
    await _online((api) => api.revokeSession(id));
    await acknowledgeSession(id);
    await sync();
  }

  // --- Key rotation ----------------------------------------------------------

  /// A member left one of my vaults: replace its key, so the old one opens
  /// nothing written from now on.
  Future<void> _rotatePending() async {
    if (_rotating) return;
    _rotating = true;
    try {
      final pending = [
        for (final v in cached?.vaults.values ?? const <VaultDto>[])
          if (v.rotationPending &&
              v.role == VaultRole.owner &&
              !_rotationFailed.contains(v.id))
            v.id,
      ];
      for (final id in pending) {
        try {
          await rotateVault(id);
        } on SecurityError catch (e) {
          _rotationFailed.add(id);
          securityWarning = e.message;
          notifyListeners();
        } on Object catch (e) {
          _rotationFailed.add(id);
          debugPrint('Schlüsselwechsel für $id fehlgeschlagen: $e');
        }
      }
    } finally {
      _rotating = false;
    }
  }

  /// Re-encrypts the vault, its recycle bin and every member's copy of the
  /// key with a fresh key. Retries when something changed meanwhile.
  Future<void> rotateVault(String vaultId) async {
    for (var attempt = 0; ; attempt++) {
      final vault = _vaults[vaultId];
      if (vault == null || phase != Phase.unlocked) return;
      final members = await this.members(vaultId);
      final trash = await _online((api) => api.trash());
      final rotation = await rotateVaultKey(
        oldKey: vault.key,
        vaultId: vaultId,
        keyVersion: vault.dto.keyVersion,
        name: vault.name,
        members: members,
        entries: [
          for (final e in cached!.entries.values)
            if (e.vaultId == vaultId && !e.deleted) e,
        ],
        trash: [
          for (final e in trash)
            if (e.vaultId == vaultId) e,
        ],
      );
      try {
        await _online((api) => api.rotateVault(vaultId, rotation.body));
        break;
      } on ApiException catch (e) {
        if (!e.conflict || attempt >= 2) rethrow;
        await _syncNow();
      }
    }
    await _syncNow();
  }

  /// A sync that waits for one already running.
  Future<void> _syncNow() async {
    final result = await _online((api) => api.sync(cached!.cursor));
    await _apply(result);
    notifyListeners();
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
    _scheduleBackup();
  }

  Future<T> _write<T>(Future<T> Function(SixoraApi api) action) async {
    try {
      return await _online(action);
    } on ApiException catch (e) {
      if (e.code == 'key_changed') {
        await sync();
        throw UserError(t.vaultKeyRenewed);
      }
      if (e.conflict) {
        await sync();
        throw UserError(t.entryChangedElsewhere);
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
      throw UserError(t.vaultReadOnly);
    }
    final id = item?.id ?? VaultCrypto.newId();
    final data = await UnlockedKeys.encryptEntry(vault.key, vaultId, id, entry);
    final dto = await _write(
      (api) => api.putEntry(
        id: id,
        vaultId: vaultId,
        data: data,
        baseRevision: item?.revision ?? 0,
        keyVersion: vault.dto.keyVersion,
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
      done++;
      progress?.call(done);
    }
    return done;
  }

  bool isDuplicate(OtpEntry e) => items.any((i) => i.entry.sameKeyAs(e));

  // --- Recycle bin -------------------------------------------------------

  /// Deleted entries of the last 30 days that this device can decrypt.
  Future<List<TrashItem>> trash() async {
    final dtos = await _online((api) => api.trash());
    final out = <TrashItem>[];
    for (final e in dtos) {
      final vault = _vaults[e.vaultId];
      if (vault == null) continue;
      try {
        out.add(
          TrashItem(
            Item(
              e.id,
              e.vaultId,
              e.revision,
              await UnlockedKeys.decryptEntry(
                vault.key,
                e.vaultId,
                e.id,
                e.data,
              ),
            ),
            e.deletedAt,
          ),
        );
      } on Object {
        // Not readable: leave it out.
      }
    }
    return out;
  }

  Future<void> restore(TrashItem t) async {
    final dto = await _write((api) => api.restoreEntry(t.item.id));
    await _storeEntry(dto);
  }

  Future<void> purge(TrashItem t) =>
      _online((api) => api.purgeEntry(t.item.id));

  // --- Vaults ----------------------------------------------------------------

  /// Returns the id of the new vault, which is known here once this returns.
  Future<String> createVault(String name) async {
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
    await _syncNow();
    return id;
  }

  Future<void> renameVault(VaultView vault, String name) async {
    final encrypted = await UnlockedKeys.encryptVaultName(
      vault.key,
      vault.id,
      name.trim(),
    );
    await _write(
      (api) => api.renameVault(
        vault.id,
        encrypted,
        keyVersion: vault.dto.keyVersion,
      ),
    );
    await sync();
  }

  Future<void> deleteVault(VaultView vault) async {
    await _online((api) => api.deleteVault(vault.id));
    await sync();
  }

  /// The vault's members, each key checked against the trusted keys.
  Future<List<MemberDto>> members(String vaultId) async {
    final list = await _online((api) => api.members(vaultId));
    await _trust([
      for (final m in list)
        (userId: m.userId, username: m.username, publicKey: m.publicKey),
    ]);
    return list;
  }

  Future<UserDto> lookupUser(String username) =>
      _online((api) => api.lookupUser(username.trim()));

  String get myFingerprint => VaultCrypto.fingerprint(account!.publicKey);

  Future<void> share(VaultView vault, UserDto user, VaultRole role) async {
    await _trust([
      (userId: user.id, username: user.username, publicKey: user.publicKey),
    ]);
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

  // --- Trusted keys ----------------------------------------------------------

  /// Checks other users' public keys before a vault key is sealed to them.
  ///
  /// A user's key pair never changes, so a key that differs from the one
  /// seen before (on any of this account's devices) can only come from the
  /// server – sealing to it would hand the vault to whoever holds it. Such a
  /// key aborts; keys seen for the first time are remembered.
  Future<void> _trust(
    List<({String userId, String username, String publicKey})> users,
  ) async {
    final c = cached!;
    final keys = _keys!;
    for (var attempt = 0; ; attempt++) {
      final known = Map<String, String>.of(c.trustedKeys);
      ({String data, int revision})? remote;
      try {
        remote = await _online((api) => api.contacts());
      } on ApiException catch (e) {
        // Servers before 0.1.5: only this device remembers.
        if (e.status != 404) rethrow;
      }
      var stored = const <String, String>{};
      if (remote != null) {
        try {
          stored = await TrustedKeys.decrypt(
            keys.userKey,
            c.account.id,
            remote.data,
          );
        } on CryptoException {
          throw SecurityError(t.trustedKeysTampered);
        }
      }
      String? clash;
      void add(String id, String key, String name) {
        final have = known[id];
        if (have == null) {
          known[id] = key;
        } else if (have != key) {
          clash ??= name;
        }
      }

      for (final e in stored.entries) {
        add(e.key, e.value, t.aContact);
      }
      for (final u in users) {
        if (u.userId != c.account.id) add(u.userId, u.publicKey, u.username);
      }
      if (clash != null) {
        throw SecurityError(t.memberKeyChanged(clash!));
      }
      c.trustedKeys
        ..clear()
        ..addAll(known);
      await store.saveAccount(c);
      if (remote == null || mapEquals(stored, known)) return;
      try {
        final data = await TrustedKeys.encrypt(
          keys.userKey,
          c.account.id,
          known,
        );
        await _online(
          (api) => api.putContacts(data, baseRevision: remote!.revision),
        );
        return;
      } on ApiException catch (e) {
        // Another device saved meanwhile: merge its keys and try again.
        if (!e.conflict || attempt >= 2) rethrow;
      }
    }
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
      throw UserError(t.currentMasterPasswordWrong);
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
    final local = isLocal;
    await logout(notice: t.accountDeletedNotice);
    if (local) LocalServer.delete();
  }

  // --- Local mode ------------------------------------------------------------

  /// No server: the data stays on this device ([LocalServer]).
  bool get isLocal => cached != null && LocalServer.isLocal(cached!.server);

  /// Opens the database of the local mode for the welcome screen;
  /// [ServerInfo.hasUsers] tells whether there is an account to open.
  static Future<(Uri, ServerInfo)> openLocal() async {
    final api = LocalServer.api();
    return (api.baseUrl, await api.info());
  }

  /// Starts over without the old local data (password and recovery key
  /// lost).
  static void deleteLocalData() => LocalServer.delete();

  /// Accounts of the local mode on their way to a server. Plaintext, so
  /// only in memory, and dropped when the app locks.
  List<({OtpEntry entry, String vault, bool personal})>? _moving;

  /// The move to a server is under way or stopped half way.
  bool get moving => _moving != null;

  /// Moves the local mode to a server: signs in there ([create]: with a
  /// new account) and stores every account there, encrypted for the
  /// account there. Accounts the server account already has (same secret)
  /// are skipped. The local database is deleted only once everything
  /// arrived; if the move stops half way it throws [MoveIncomplete] and
  /// [finishMove] goes on. Returns the recovery key of a new account.
  Future<({int moved, String? recoveryKey})> moveToServer({
    required Uri server,
    required String serverName,
    required String username,
    required String password,
    required bool create,
    String? inviteCode,
    void Function(int done, int total)? progress,
  }) async {
    if (!isLocal || _keys == null) throw StateError('not in local mode');
    final carried = [
      for (final i in items)
        (
          entry: i.entry,
          vault: _vaults[i.vaultId]!.name,
          personal: _vaults[i.vaultId]!.personal,
        ),
    ];
    BackupKey? backup;
    try {
      backup = await _backupKey();
    } on Object {
      backup = null;
    }
    final localKeys = _keys!;
    final localVaults = _vaults.values.toList();
    _stopWatching();
    _backupTimer?.cancel();
    String? recoveryKey;
    try {
      if (create) {
        recoveryKey = await register(
          server: server,
          serverName: serverName,
          username: username,
          password: password,
          inviteCode: inviteCode,
        );
      } else {
        await login(
          server: server,
          serverName: serverName,
          username: username,
          password: password,
        );
      }
    } on Object {
      if (isLocal && phase == Phase.unlocked) _startWatching();
      rethrow;
    }
    // From here on the account on the server is the one of this app.
    localKeys.userKey.fillRange(0, localKeys.userKey.length, 0);
    localKeys.privateKey.fillRange(0, localKeys.privateKey.length, 0);
    for (final v in localVaults) {
      _vaults.remove(v.id);
      v.key.fillRange(0, v.key.length, 0);
    }
    try {
      if (create) await enter();
      // The automatic backup goes on, now with the account there.
      if (backup != null) await _storeBackupKey(backup);
      await _syncNow();
      _moving = [
        for (final c in carried)
          if (!items.any((i) => i.entry.sameKeyAs(c.entry))) c,
      ];
      return (
        moved: await finishMove(progress: progress),
        recoveryKey: recoveryKey,
      );
    } on Object catch (e) {
      throw MoveIncomplete(t.moveIncomplete(errorText(e)), recoveryKey);
    }
  }

  /// Stores the rest of an interrupted move; returns how many arrived.
  Future<int> finishMove({void Function(int done, int total)? progress}) async {
    final pending = _moving;
    if (pending == null) return 0;
    final total = pending.length;
    var done = 0;
    while (pending.isNotEmpty) {
      final next = pending.first;
      await saveEntry(
        next.entry,
        vaultId: await _moveTarget(next.vault, next.personal),
      );
      pending.removeAt(0);
      done++;
      progress?.call(done, total);
    }
    _moving = null;
    LocalServer.delete();
    notifyListeners();
    return done;
  }

  /// The personal vault for personal accounts, else a vault of the same
  /// name (created if needed).
  Future<String> _moveTarget(String name, bool personal) async {
    final own = [
      for (final v in _vaults.values)
        if (v.canWrite) v,
    ];
    if (personal) {
      for (final v in own) {
        if (v.personal) return v.id;
      }
    }
    for (final v in own) {
      if (!v.personal && v.name == name) return v.id;
    }
    return createVault(name);
  }

  @override
  void dispose() {
    _stopWatching();
    _api?.close();
    super.dispose();
  }
}
