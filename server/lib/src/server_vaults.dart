part of 'server_app.dart';

/// Vaults, members, key rotation and user lookup.
extension _VaultApi on SixoraServerApp {
  Future<Response> _createVault(Request request) async {
    final s = _auth(request);
    final body = await _body(request);
    final id = _uuid(body['id'], 'Tresor-ID');
    final name = _b64(body, 'encryptedName', min: 41, max: 2000);
    final sealed = _b64(body, 'sealedKey', min: 73, max: 300);
    _transaction(() {
      final count =
          db.select('SELECT COUNT(*) AS n FROM vaults WHERE owner_id = ?', [
                s.userId,
              ]).first['n']
              as int;
      if (count >= SixoraServerApp.maxVaultsPerUser) {
        throw const ApiError(409, 'limit', 'Zu viele Tresore');
      }
      if (db.select('SELECT 1 FROM vaults WHERE id = ?', [id]).isNotEmpty) {
        throw const ApiError(409, 'conflict', 'ID bereits vergeben');
      }
      db.execute(
        'INSERT INTO vaults (id, owner_id, personal, encrypted_name, created_at) '
        'VALUES (?, ?, 0, ?, ?)',
        [id, s.userId, name, _now()],
      );
      db.execute(
        'INSERT INTO vault_members (vault_id, user_id, role, sealed_key, seq, added_at) '
        "VALUES (?, ?, 'owner', ?, ?, ?)",
        [id, s.userId, sealed, _nextSeq(), _now()],
      );
    });
    return _json({'ok': true}, status: 201);
  }

  Future<Response> _renameVault(Request request, String id) async {
    final s = _auth(request);
    final body = await _body(request);
    final name = _b64(body, 'encryptedName', min: 41, max: 2000);
    final keyVersion = body['keyVersion'];
    _requireMember(id, s.userId, owner: true);
    _transaction(() {
      if (keyVersion is int &&
          db.select('SELECT key_version FROM vaults WHERE id = ?', [
                id,
              ]).first['key_version'] !=
              keyVersion) {
        throw const ApiError(
          409,
          'key_changed',
          'Der Tresorschlüssel wurde erneuert. Bitte erneut versuchen.',
        );
      }
      db.execute('UPDATE vaults SET encrypted_name = ? WHERE id = ?', [
        name,
        id,
      ]);
      _nextSeq();
    });
    return _ok();
  }

  Response _deleteVault(Request request, String id) {
    final s = _auth(request);
    _requireMember(id, s.userId, owner: true);
    final personal = db.select('SELECT personal FROM vaults WHERE id = ?', [
      id,
    ]).first['personal'];
    if (personal == 1) {
      throw const ApiError(
        409,
        'personal',
        'Der persönliche Tresor kann nicht gelöscht werden',
      );
    }
    _transaction(() {
      db.execute('DELETE FROM vaults WHERE id = ?', [id]);
      _nextSeq();
      _audit(
        'vault_deleted',
        userId: s.userId,
        username: s.username,
        detail: id,
        ip: _ip(request),
      );
    });
    return _ok();
  }

  Response _members(Request request, String id) {
    final s = _auth(request);
    _requireMember(id, s.userId);
    final rows = db.select(
      'SELECT m.user_id, m.role, u.username, u.public_key FROM vault_members m '
      "JOIN users u ON u.id = m.user_id WHERE m.vault_id = ? "
      "ORDER BY m.role = 'owner' DESC, u.username",
      [id],
    );
    return _json({
      'members': [
        for (final r in rows)
          {
            'userId': r['user_id'],
            'username': r['username'],
            'role': r['role'],
            'publicKey': r['public_key'],
          },
      ],
    });
  }

  Future<Response> _putMember(Request request, String id, String userId) async {
    final s = _auth(request);
    final body = await _body(request);
    final sealed = _b64(body, 'sealedKey', min: 73, max: 300);
    final role = body['role'];
    if (role != 'read' && role != 'write') {
      throw const FormatException('Rolle ist ungültig');
    }
    _requireMember(id, s.userId, owner: true);
    if (userId == s.userId) {
      throw const ApiError(
        400,
        'bad_request',
        'Eigene Rolle kann nicht geändert werden',
      );
    }
    final vault = db.select('SELECT personal FROM vaults WHERE id = ?', [
      id,
    ]).first;
    if (vault['personal'] == 1) {
      throw const ApiError(
        409,
        'personal',
        'Der persönliche Tresor kann nicht geteilt werden. Bitte einen eigenen Tresor zum Teilen anlegen.',
      );
    }
    final target = db.select(
      'SELECT username, disabled FROM users WHERE id = ?',
      [userId],
    );
    if (target.isEmpty || target.first['disabled'] == 1) {
      throw const ApiError(404, 'not_found', 'Benutzer nicht gefunden');
    }
    _transaction(() {
      final existing = _membership(id, userId);
      if (existing == null) {
        db.execute(
          'INSERT INTO vault_members (vault_id, user_id, role, sealed_key, seq, added_at) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [id, userId, role, sealed, _nextSeq(), _now()],
        );
      } else {
        // A role change keeps the member's local copy valid.
        db.execute(
          'UPDATE vault_members SET role = ?, sealed_key = ? WHERE vault_id = ? AND user_id = ?',
          [role, sealed, id, userId],
        );
        _nextSeq();
      }
      _audit(
        'vault_shared',
        userId: s.userId,
        username: s.username,
        detail: '${target.first['username']} ($role)',
        ip: _ip(request),
      );
    });
    return _ok();
  }

  Response _removeMember(Request request, String id, String userId) {
    final s = _auth(request);
    final mine = _requireMember(id, s.userId);
    final leaving = userId == s.userId;
    if (!leaving && mine['role'] != 'owner') {
      throw const ApiError(
        403,
        'forbidden',
        'Nur der Eigentümer darf Mitglieder entfernen',
      );
    }
    if (leaving && mine['role'] == 'owner') {
      throw const ApiError(
        409,
        'owner',
        'Der Eigentümer kann den Tresor nicht verlassen, nur löschen',
      );
    }
    final target = _membership(id, userId);
    if (target == null) {
      throw const ApiError(404, 'not_found', 'Mitglied nicht gefunden');
    }
    _transaction(() {
      db.execute(
        'DELETE FROM vault_members WHERE vault_id = ? AND user_id = ?',
        [id, userId],
      );
      // The former member still knows the vault key: the owner's next
      // device online replaces it.
      db.execute('UPDATE vaults SET rotate_pending = 1 WHERE id = ?', [id]);
      _nextSeq();
      _audit(
        leaving ? 'vault_left' : 'vault_unshared',
        userId: s.userId,
        username: s.username,
        detail: userId,
        ip: _ip(request),
      );
    });
    return _ok();
  }

  /// Vaults shared with [userId] (not owned) need a new key once the user
  /// is gone.
  void _markRotationFor(String userId) => db.execute(
    'UPDATE vaults SET rotate_pending = 1 WHERE id IN '
    "(SELECT vault_id FROM vault_members WHERE user_id = ? AND role != 'owner')",
    [userId],
  );

  /// Replaces the vault key: every entry (also in the recycle bin), the name
  /// and every member's sealed key arrive re-encrypted at once. The request
  /// must cover exactly the current members and entries, otherwise
  /// something changed meanwhile and the client tries again.
  Future<Response> _rotateVault(Request request, String id) async {
    final s = _auth(request);
    final body = await _body(request, maxBytes: SixoraServerApp.maxRotateBytes);
    final keyVersion = body['keyVersion'];
    if (keyVersion is! int) throw const FormatException('keyVersion fehlt');
    final name = _b64(body, 'encryptedName', min: 41, max: 2000);
    final members = <String, String>{};
    for (final m in body['members'] as List? ?? const []) {
      if (m is! Map) throw const FormatException('members ist ungültig');
      final map = m.cast<String, Object?>();
      members[_uuid(map['userId'], 'Benutzer-ID')] = _b64(
        map,
        'sealedKey',
        min: 73,
        max: 300,
      );
    }
    ({Map<String, String> data, Map<String, int> revisions}) parse(String key) {
      final data = <String, String>{};
      final revisions = <String, int>{};
      for (final e in body[key] as List? ?? const []) {
        if (e is! Map) throw FormatException('$key ist ungültig');
        final map = e.cast<String, Object?>();
        final entryId = _uuid(map['id'], 'Eintrags-ID');
        final rev = map['revision'];
        if (rev is! int) throw FormatException('$key: revision fehlt');
        data[entryId] = _b64(
          map,
          'data',
          min: 41,
          max: SixoraServerApp.maxEntryBytes,
        );
        revisions[entryId] = rev;
      }
      return (data: data, revisions: revisions);
    }

    final entries = parse('entries');
    final trash = parse('trash');
    _transaction(() {
      _requireMember(id, s.userId, owner: true);
      final vault = db.select('SELECT key_version FROM vaults WHERE id = ?', [
        id,
      ]).first;
      if (vault['key_version'] != keyVersion) {
        throw const ApiError(
          409,
          'key_changed',
          'Der Tresorschlüssel wurde inzwischen erneuert',
        );
      }
      bool same(Map<String, int> sent, ResultSet rows) =>
          rows.length == sent.length &&
          rows.every((r) => sent[r['id']] == r['revision']);
      final current = db.select(
        'SELECT user_id FROM vault_members WHERE vault_id = ?',
        [id],
      );
      final live = db.select(
        'SELECT id, revision FROM entries WHERE vault_id = ? AND deleted = 0',
        [id],
      );
      final trashed = db.select(
        'SELECT id, revision FROM entries WHERE vault_id = ? AND deleted = 1 '
        "AND trash_data != ''",
        [id],
      );
      if (current.length != members.length ||
          !current.every((r) => members.containsKey(r['user_id'])) ||
          !same(entries.revisions, live) ||
          !same(trash.revisions, trashed)) {
        throw const ApiError(
          409,
          'conflict',
          'Der Tresor wurde inzwischen geändert',
        );
      }
      final now = _now();
      db.execute(
        'UPDATE vaults SET encrypted_name = ?, key_version = key_version + 1, '
        'rotate_pending = 0 WHERE id = ?',
        [name, id],
      );
      // A new member seq makes every member load the vault anew.
      for (final m in members.entries) {
        db.execute(
          'UPDATE vault_members SET sealed_key = ?, seq = ? '
          'WHERE vault_id = ? AND user_id = ?',
          [m.value, _nextSeq(), id, m.key],
        );
      }
      for (final e in entries.data.entries) {
        db.execute(
          'UPDATE entries SET data = ?, revision = revision + 1, seq = ?, '
          'updated_at = ?, updated_by = ? WHERE id = ?',
          [e.value, _nextSeq(), now, s.userId, e.key],
        );
      }
      for (final e in trash.data.entries) {
        db.execute('UPDATE entries SET trash_data = ? WHERE id = ?', [
          e.value,
          e.key,
        ]);
      }
      _audit(
        'vault_key_rotated',
        userId: s.userId,
        username: s.username,
        detail: '$id (${entries.data.length} Einträge)',
        ip: _ip(request),
      );
    });
    return _ok();
  }

  Response _lookupUser(Request request) {
    _auth(request);
    final name = request.url.queryParameters['username']?.trim() ?? '';
    final u = name.isEmpty ? null : _userByName(name);
    if (u == null || u['disabled'] == 1) {
      throw const ApiError(404, 'not_found', 'Benutzer nicht gefunden');
    }
    return _json({
      'id': u['id'],
      'username': u['username'],
      'publicKey': u['public_key'],
    });
  }
}
