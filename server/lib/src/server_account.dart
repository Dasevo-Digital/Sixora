part of 'server_app.dart';

/// The signed-in account: password, recovery key, sessions, trusted keys, activity.
extension _AccountApi on SixoraServerApp {
  Response _logout(Request request) {
    final s = _auth(request);
    db.execute('DELETE FROM sessions WHERE id = ?', [s.id]);
    _nextSeq();
    _audit('logout', userId: s.userId, username: s.username, ip: _ip(request));
    return _ok();
  }

  Response _account(Request request) =>
      _json(_accountJson(_auth(request).userId));

  Future<Response> _changePassword(Request request) async {
    final s = _auth(request);
    final body = await _body(request);
    _verifyCurrent(s, request, _str(body, 'authKey', max: 100));
    final kdf = _kdf(body['newKdf']);
    final salt = _b64(body, 'newSalt', min: 16, max: 64);
    final authKey = _b64(body, 'newAuthKey', min: 32, max: 32);
    final wrapped = _b64(body, 'newWrappedUserKey', min: 41, max: 200);
    _transaction(() {
      db.execute(
        'UPDATE users SET kdf = ?, salt = ?, auth_hash = ?, wrapped_user_key = ?, '
        'updated_at = ? WHERE id = ?',
        [kdf, salt, sha256Hex(authKey), wrapped, _now(), s.userId],
      );
      db.execute('DELETE FROM sessions WHERE user_id = ? AND id != ?', [
        s.userId,
        s.id,
      ]);
      _nextSeq();
      _audit(
        'password_changed',
        userId: s.userId,
        username: s.username,
        detail: 'andere Geräte abgemeldet',
        ip: _ip(request),
      );
    });
    return _ok();
  }

  Future<Response> _setRecovery(Request request) async {
    final s = _auth(request);
    final body = await _body(request);
    _verifyCurrent(s, request, _str(body, 'authKey', max: 100));
    final wrapped = _b64(body, 'recoveryWrappedUserKey', min: 41, max: 200);
    final auth = _b64(body, 'recoveryAuth', min: 32, max: 32);
    db.execute(
      'UPDATE users SET recovery_wrapped_user_key = ?, recovery_auth_hash = ?, '
      'updated_at = ? WHERE id = ?',
      [wrapped, sha256Hex(auth), _now(), s.userId],
    );
    _audit(
      'recovery_key_changed',
      userId: s.userId,
      username: s.username,
      ip: _ip(request),
    );
    return _ok();
  }

  Future<Response> _deleteAccount(Request request) async {
    final s = _auth(request);
    final body = await _body(request);
    _verifyCurrent(s, request, _str(body, 'authKey', max: 100));
    _transaction(() {
      _ensureNotLastAdmin(s.userId);
      _markRotationFor(s.userId);
      db.execute('DELETE FROM users WHERE id = ?', [s.userId]);
      _nextSeq();
      _audit(
        'account_deleted',
        userId: s.userId,
        username: s.username,
        ip: _ip(request),
      );
    });
    return _ok();
  }

  void _ensureNotLastAdmin(String userId) {
    final admins = db
        .select('SELECT id FROM users WHERE is_admin = 1 AND disabled = 0')
        .map((r) => r['id'])
        .toList();
    final others = db.select('SELECT 1 FROM users WHERE id != ? LIMIT 1', [
      userId,
    ]);
    if (admins.length == 1 && admins.single == userId && others.isNotEmpty) {
      throw const ApiError(
        409,
        'last_admin',
        'Der letzte Administrator kann nicht entfernt werden. '
            'Bitte zuerst einen anderen Benutzer zum Administrator machen.',
      );
    }
  }

  /// The account's trusted public keys of other users, encrypted by the
  /// client. The server only keeps the newest version.
  Response _contacts(Request request) {
    final s = _auth(request);
    final u = db.select(
      'SELECT contacts, contacts_revision FROM users WHERE id = ?',
      [s.userId],
    ).first;
    return _json({'data': u['contacts'], 'revision': u['contacts_revision']});
  }

  Future<Response> _putContacts(Request request) async {
    final s = _auth(request);
    final body = await _body(request);
    final data = _b64(
      body,
      'data',
      min: 41,
      max: SixoraServerApp.maxContactsBytes,
    );
    final base = body['baseRevision'];
    if (base is! int || base < 0) {
      throw const FormatException('baseRevision fehlt');
    }
    final revision = _transaction(() {
      final current =
          db.select('SELECT contacts_revision FROM users WHERE id = ?', [
                s.userId,
              ]).first['contacts_revision']
              as int;
      if (current != base) {
        throw const ApiError(
          409,
          'conflict',
          'Die bekannten Schlüssel wurden auf einem anderen Gerät geändert',
        );
      }
      db.execute(
        'UPDATE users SET contacts = ?, contacts_revision = ? WHERE id = ?',
        [data, current + 1, s.userId],
      );
      return current + 1;
    });
    return _json({'revision': revision});
  }

  Response _sessions(Request request) {
    final s = _auth(request);
    final rows = db.select(
      'SELECT * FROM sessions WHERE user_id = ? ORDER BY last_seen_at DESC',
      [s.userId],
    );
    return _json({
      'sessions': [
        for (final r in rows)
          {
            'id': r['id'],
            'deviceName': r['device_name'],
            'platform': r['platform'],
            'createdAt': r['created_at'],
            'lastSeenAt': r['last_seen_at'],
            'current': r['id'] == s.id,
          },
      ],
    });
  }

  Response _revokeSession(Request request, String id) {
    final s = _auth(request);
    final rows = db.select(
      'SELECT device_name FROM sessions WHERE id = ? AND user_id = ?',
      [id, s.userId],
    );
    if (rows.isEmpty) {
      throw const ApiError(404, 'not_found', 'Gerät nicht gefunden');
    }
    db.execute('DELETE FROM sessions WHERE id = ?', [id]);
    _nextSeq();
    _audit(
      'session_revoked',
      userId: s.userId,
      username: s.username,
      detail: rows.first['device_name'] as String,
      ip: _ip(request),
    );
    return _ok();
  }

  Response _accountAudit(Request request) {
    final s = _auth(request);
    return _auditJson(
      db.select(
        'SELECT * FROM audit WHERE user_id = ? ORDER BY id DESC LIMIT 200',
        [s.userId],
      ),
    );
  }
}
