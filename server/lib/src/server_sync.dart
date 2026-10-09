part of 'server_app.dart';

/// Vault membership checks, sync (long poll), entries and the recycle bin.
extension _SyncApi on SixoraServerApp {
  Row? _membership(String vaultId, String userId) {
    final rows = db.select(
      'SELECT * FROM vault_members WHERE vault_id = ? AND user_id = ?',
      [vaultId, userId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Row _requireMember(
    String vaultId,
    String userId, {
    bool write = false,
    bool owner = false,
  }) {
    final m = _membership(vaultId, userId);
    if (m == null) {
      throw const ApiError(404, 'not_found', 'Tresor nicht gefunden');
    }
    final role = m['role'] as String;
    if (owner && role != 'owner') {
      throw const ApiError(403, 'forbidden', 'Nur der Eigentümer darf das');
    }
    if (write && role == 'read') {
      throw const ApiError(
        403,
        'read_only',
        'Dieser Tresor ist schreibgeschützt geteilt',
      );
    }
    return m;
  }

  Future<Response> _sync(Request request) async {
    final s = _auth(request);
    final since =
        int.tryParse(request.url.queryParameters['since'] ?? '0') ?? 0;
    // Long poll: with `wait`, an unchanged state holds the request until
    // something changes or the time is up – changes from other devices
    // arrive at once instead of with the next poll.
    final wait = int.tryParse(request.url.queryParameters['wait'] ?? '') ?? 0;
    if (wait > 0 && since > 0 && _currentSeq() <= since) {
      final limit = Duration(
        seconds: wait.clamp(1, SixoraServerApp.maxSyncWait.inSeconds),
      );
      await _changed.next.timeout(limit, onTimeout: () {});
    }
    final cursor = _currentSeq();
    final vaults = db.select(
      'SELECT v.id, v.personal, v.owner_id, v.encrypted_name, v.key_version, '
      'v.rotate_pending, o.username AS owner_name, '
      'm.role, m.sealed_key, m.seq, '
      '(SELECT COUNT(*) FROM vault_members x WHERE x.vault_id = v.id) AS member_count '
      'FROM vault_members m JOIN vaults v ON v.id = m.vault_id '
      'JOIN users o ON o.id = v.owner_id WHERE m.user_id = ? '
      'ORDER BY v.personal DESC, v.created_at',
      [s.userId],
    );
    final reset = <String>[];
    final entries = <Map<String, Object?>>[];
    for (final v in vaults) {
      final id = v['id'] as String;
      final full = since <= 0 || (v['seq'] as int) > since;
      final ResultSet rows;
      if (full) {
        reset.add(id);
        rows = db.select(
          'SELECT * FROM entries WHERE vault_id = ? AND deleted = 0 AND seq <= ?',
          [id, cursor],
        );
      } else {
        rows = db.select(
          'SELECT * FROM entries WHERE vault_id = ? AND seq > ? AND seq <= ?',
          [id, since, cursor],
        );
      }
      entries.addAll(rows.map(_entryJson));
    }
    return _json({
      'cursor': cursor,
      'resetVaults': reset,
      'vaults': [
        for (final v in vaults)
          {
            'id': v['id'],
            'personal': v['personal'] == 1,
            'ownerId': v['owner_id'],
            'ownerName': v['owner_name'],
            'role': v['role'],
            'encryptedName': v['encrypted_name'],
            'sealedKey': v['sealed_key'],
            'memberCount': v['member_count'],
            'keyVersion': v['key_version'],
            if (v['role'] == 'owner')
              'rotationPending': v['rotate_pending'] == 1,
          },
      ],
      'entries': entries,
      // Lets every device notice a sign-in it does not know.
      'sessions': [
        for (final r in db.select(
          'SELECT id, device_name, platform, created_at FROM sessions '
          'WHERE user_id = ? ORDER BY created_at',
          [s.userId],
        ))
          {
            'id': r['id'],
            'deviceName': r['device_name'],
            'platform': r['platform'],
            'createdAt': r['created_at'],
            'current': r['id'] == s.id,
          },
      ],
    });
  }

  Future<Response> _putEntry(Request request, String id) async {
    final s = _auth(request);
    _uuid(id, 'Eintrags-ID');
    final body = await _body(request);
    final vaultId = _uuid(body['vaultId'], 'Tresor-ID');
    final data = _b64(
      body,
      'data',
      min: 41,
      max: SixoraServerApp.maxEntryBytes,
    );
    final base = body['baseRevision'];
    if (base is! int || base < 0) {
      throw const FormatException('baseRevision fehlt');
    }
    final keyVersion = body['keyVersion'];
    final row = _transaction(() {
      _requireMember(vaultId, s.userId, write: true);
      // Written with a key that was replaced meanwhile: nobody could read it.
      if (keyVersion is int &&
          db.select('SELECT key_version FROM vaults WHERE id = ?', [
                vaultId,
              ]).first['key_version'] !=
              keyVersion) {
        throw const ApiError(
          409,
          'key_changed',
          'Der Tresorschlüssel wurde erneuert. Bitte erneut versuchen.',
        );
      }
      final existing = db.select('SELECT * FROM entries WHERE id = ?', [id]);
      if (existing.isEmpty) {
        if (base != 0) {
          throw const ApiError(
            409,
            'conflict',
            'Eintrag wurde inzwischen gelöscht',
          );
        }
        final count =
            db.select(
                  'SELECT COUNT(*) AS n FROM entries WHERE vault_id = ? AND deleted = 0',
                  [vaultId],
                ).first['n']
                as int;
        if (count >= SixoraServerApp.maxEntriesPerVault) {
          throw const ApiError(
            409,
            'limit',
            'Zu viele Einträge in diesem Tresor',
          );
        }
        db.execute(
          'INSERT INTO entries (id, vault_id, data, revision, deleted, seq, updated_at, updated_by) '
          'VALUES (?, ?, ?, 1, 0, ?, ?, ?)',
          [id, vaultId, data, _nextSeq(), _now(), s.userId],
        );
      } else {
        final e = existing.first;
        if (e['vault_id'] != vaultId) {
          throw const ApiError(
            409,
            'conflict',
            'Eintrag gehört zu einem anderen Tresor',
          );
        }
        if (e['revision'] != base) {
          throw ApiError(
            409,
            'conflict',
            'Eintrag wurde auf einem anderen Gerät geändert (Revision ${e['revision']})',
          );
        }
        db.execute(
          'UPDATE entries SET data = ?, revision = revision + 1, deleted = 0, seq = ?, '
          "updated_at = ?, updated_by = ?, deleted_at = NULL, trash_data = '' WHERE id = ?",
          [data, _nextSeq(), _now(), s.userId, id],
        );
      }
      return db.select('SELECT * FROM entries WHERE id = ?', [id]).first;
    });
    return _json(_entryJson(row));
  }

  Response _deleteEntry(Request request, String id) {
    final s = _auth(request);
    final base = int.tryParse(
      request.url.queryParameters['baseRevision'] ?? '',
    );
    if (base == null) throw const FormatException('baseRevision fehlt');
    final row = _transaction(() {
      final existing = db.select('SELECT * FROM entries WHERE id = ?', [id]);
      if (existing.isEmpty) {
        throw const ApiError(404, 'not_found', 'Eintrag nicht gefunden');
      }
      final e = existing.first;
      _requireMember(e['vault_id'] as String, s.userId, write: true);
      if (e['deleted'] == 1) return e;
      if (e['revision'] != base) {
        throw const ApiError(
          409,
          'conflict',
          'Eintrag wurde auf einem anderen Gerät geändert',
        );
      }
      // Into the recycle bin: the ciphertext moves to trash_data.
      db.execute(
        "UPDATE entries SET trash_data = data, data = '', revision = revision + 1, "
        'deleted = 1, deleted_at = ?, seq = ?, updated_at = ?, updated_by = ? '
        'WHERE id = ?',
        [_now(), _nextSeq(), _now(), s.userId, id],
      );
      return db.select('SELECT * FROM entries WHERE id = ?', [id]).first;
    });
    return _json(_entryJson(row));
  }

  // --- Recycle bin -----------------------------------------------------------

  /// Deleted entries of the last 30 days in the user's vaults (encrypted).
  Response _trash(Request request) {
    final s = _auth(request);
    final rows = db.select(
      'SELECT e.* FROM entries e JOIN vault_members m ON m.vault_id = e.vault_id '
      "WHERE m.user_id = ? AND e.deleted = 1 AND e.trash_data != '' "
      'ORDER BY e.deleted_at DESC',
      [s.userId],
    );
    return _json({
      'entries': [
        for (final r in rows)
          {
            ..._entryJson(r),
            'data': r['trash_data'],
            'deletedAt': r['deleted_at'],
          },
      ],
    });
  }

  Row _trashed(String id, String userId) {
    final rows = db.select(
      "SELECT * FROM entries WHERE id = ? AND deleted = 1 AND trash_data != ''",
      [id],
    );
    if (rows.isEmpty) {
      throw const ApiError(404, 'not_found', 'Nicht im Papierkorb');
    }
    _requireMember(rows.first['vault_id'] as String, userId, write: true);
    return rows.first;
  }

  Future<Response> _restoreEntry(Request request, String id) async {
    final s = _auth(request);
    final row = _transaction(() {
      _trashed(id, s.userId);
      db.execute(
        "UPDATE entries SET data = trash_data, trash_data = '', deleted = 0, "
        'deleted_at = NULL, revision = revision + 1, seq = ?, updated_at = ?, '
        'updated_by = ? WHERE id = ?',
        [_nextSeq(), _now(), s.userId, id],
      );
      return db.select('SELECT * FROM entries WHERE id = ?', [id]).first;
    });
    return _json(_entryJson(row));
  }

  /// Removes the ciphertext for good; the tombstone stays for sync.
  Response _purgeEntry(Request request, String id) {
    final s = _auth(request);
    _transaction(() {
      _trashed(id, s.userId);
      db.execute("UPDATE entries SET trash_data = '' WHERE id = ?", [id]);
    });
    return _ok();
  }
}
