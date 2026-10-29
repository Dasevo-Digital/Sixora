part of 'app_controller.dart';

extension AppControllerMove on AppController {
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
      // Not enter(): its offer of Face ID & co. would open a dialog over
      // the move and swallow its result. The move screen points to the
      // settings instead (the old quick unlock belonged to the local
      // account).
      if (create) await _afterUnlock();
      offerBiometrics = false;
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
    _notify();
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
}
