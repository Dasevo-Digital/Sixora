part of 'app_controller.dart';

extension AppControllerBackup on AppController {
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
    _notify();
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
      _notify();
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
}
