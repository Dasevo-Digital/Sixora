part of 'server_app.dart';

/// Administration: users, invites, server-wide activity.
extension _AdminApi on SixoraServerApp {
  Response _adminUsers(Request request) {
    _admin(request);
    final rows = db.select('SELECT * FROM users ORDER BY username');
    return _json({
      'users': [
        for (final u in rows)
          {
            'id': u['id'],
            'username': u['username'],
            'publicKey': u['public_key'],
            'isAdmin': u['is_admin'] == 1,
            'disabled': u['disabled'] == 1,
            'createdAt': u['created_at'],
          },
      ],
    });
  }

  Future<Response> _adminUpdateUser(Request request, String id) async {
    final s = _admin(request);
    final body = await _body(request);
    final disabled = body['disabled'];
    final isAdmin = body['isAdmin'];
    final rows = db.select('SELECT username FROM users WHERE id = ?', [id]);
    if (rows.isEmpty) {
      throw const ApiError(404, 'not_found', 'Benutzer nicht gefunden');
    }
    if (id == s.userId && (disabled == true || isAdmin == false)) {
      throw const ApiError(
        409,
        'self',
        'Das eigene Konto kann hier nicht herabgestuft werden',
      );
    }
    _transaction(() {
      if (disabled is bool) {
        db.execute('UPDATE users SET disabled = ? WHERE id = ?', [
          disabled ? 1 : 0,
          id,
        ]);
        if (disabled) {
          db.execute('DELETE FROM sessions WHERE user_id = ?', [id]);
        }
      }
      if (isAdmin is bool) {
        db.execute('UPDATE users SET is_admin = ? WHERE id = ?', [
          isAdmin ? 1 : 0,
          id,
        ]);
      }
      _audit(
        'admin_user_updated',
        userId: s.userId,
        username: s.username,
        detail:
            '${rows.first['username']}: '
                    '${disabled is bool ? (disabled ? 'gesperrt ' : 'entsperrt ') : ''}'
                    '${isAdmin is bool ? (isAdmin ? 'Administrator' : 'kein Administrator') : ''}'
                .trim(),
        ip: _ip(request),
      );
    });
    return _ok();
  }

  Response _adminDeleteUser(Request request, String id) {
    final s = _admin(request);
    if (id == s.userId) {
      throw const ApiError(
        409,
        'self',
        'Das eigene Konto bitte in den Kontoeinstellungen löschen',
      );
    }
    final rows = db.select('SELECT username FROM users WHERE id = ?', [id]);
    if (rows.isEmpty) {
      throw const ApiError(404, 'not_found', 'Benutzer nicht gefunden');
    }
    _transaction(() {
      _markRotationFor(id);
      db.execute('DELETE FROM users WHERE id = ?', [id]);
      _nextSeq();
      _audit(
        'admin_user_deleted',
        userId: s.userId,
        username: s.username,
        detail: rows.first['username'] as String,
        ip: _ip(request),
      );
    });
    return _ok();
  }

  Response _adminInvites(Request request) {
    _admin(request);
    final rows = db.select(
      'SELECT * FROM invites WHERE expires_at > ? ORDER BY created_at DESC',
      [_now()],
    );
    return _json({
      'invites': [
        for (final r in rows)
          {
            'id': r['id'],
            'note': r['note'],
            'createdAt': r['created_at'],
            'expiresAt': r['expires_at'],
          },
      ],
    });
  }

  Future<Response> _adminCreateInvite(Request request) async {
    final s = _admin(request);
    final body = await _body(request);
    final days = body['days'] is int ? (body['days'] as int).clamp(1, 90) : 7;
    final note = _str(body, 'note', max: 100, required: false).trim();
    final invite = createInvite(days: days, note: note, createdBy: s.userId);
    _audit(
      'invite_created',
      userId: s.userId,
      username: s.username,
      detail: note,
      ip: _ip(request),
    );
    return _json(invite, status: 201);
  }

  Response _adminDeleteInvite(Request request, String id) {
    final s = _admin(request);
    db.execute('DELETE FROM invites WHERE id = ?', [id]);
    _audit(
      'invite_deleted',
      userId: s.userId,
      username: s.username,
      ip: _ip(request),
    );
    return _ok();
  }

  Response _adminAudit(Request request) {
    _admin(request);
    return _auditJson(
      db.select('SELECT * FROM audit ORDER BY id DESC LIMIT 500'),
    );
  }
}
