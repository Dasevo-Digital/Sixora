part of 'server_app.dart';

/// Registration, sign-in and password recovery.
extension _AuthApi on SixoraServerApp {
  Future<Response> _prelogin(Request request) async {
    final body = await _body(request);
    final username = _str(body, 'username', max: 64).trim();
    final user = _userByName(username);
    if (user != null) {
      return _json({
        'kdf': jsonDecode(user['kdf'] as String),
        'salt': user['salt'],
      });
    }
    // Unknown users get a stable fake salt and the parameters of the newest
    // account (what current clients create), so the answer does not reveal
    // which accounts exist.
    final fake = Hmac(sha256, utf8.encode(_secret))
        .convert(utf8.encode('salt|${username.toLowerCase()}'))
        .bytes
        .sublist(0, 16);
    final newest = db.select(
      'SELECT kdf FROM users ORDER BY created_at DESC LIMIT 1',
    );
    return _json({
      'kdf': newest.isEmpty
          ? {'alg': 'argon2id', 'm': 65536, 't': 3, 'p': 1}
          : jsonDecode(newest.first['kdf'] as String),
      'salt': base64.encode(fake),
    });
  }

  Future<Response> _register(Request request) async {
    final body = await _body(request);
    final username = _str(body, 'username', max: 64).trim();
    if (!_usernamePattern.hasMatch(username)) {
      throw const ApiError(
        400,
        'invalid_username',
        'Benutzername: 3–64 Zeichen, Buchstaben, Ziffern und . _ @ + -',
      );
    }
    final userId = _uuid(body['userId'], 'Benutzer-ID');
    final kdf = _kdf(body['kdf']);
    final salt = _b64(body, 'salt', min: 16, max: 64);
    final authKey = _b64(body, 'authKey', min: 32, max: 32);
    final wrappedUserKey = _b64(body, 'wrappedUserKey', min: 41, max: 200);
    final publicKey = _b64(body, 'publicKey', min: 32, max: 32);
    final encryptedPrivateKey = _b64(
      body,
      'encryptedPrivateKey',
      min: 41,
      max: 200,
    );
    final recoveryWrapped = _b64(
      body,
      'recoveryWrappedUserKey',
      min: 41,
      max: 200,
    );
    final recoveryAuth = _b64(body, 'recoveryAuth', min: 32, max: 32);
    final vault = body['personalVault'];
    if (vault is! Map) throw const FormatException('personalVault fehlt');
    final v = vault.cast<String, Object?>();
    final vaultId = _uuid(v['id'], 'Tresor-ID');
    final vaultName = _b64(v, 'encryptedName', min: 41, max: 2000);
    final sealedKey = _b64(v, 'sealedKey', min: 73, max: 300);
    final inviteCode = body['inviteCode'] is String
        ? body['inviteCode'] as String
        : '';
    final ip = _ip(request);

    final token = _transaction(() {
      final first = !_hasUsers;
      String? inviteId;
      if (!first) {
        switch (registration) {
          case Registration.closed:
            throw const ApiError(
              403,
              'registration_closed',
              'Registrierung ist geschlossen',
            );
          case Registration.invite:
            if (_ipFailures.blocked('ip:$ip')) {
              throw const ApiError(
                429,
                'rate_limited',
                'Zu viele Fehlversuche',
              );
            }
            final rows = db.select(
              'SELECT id FROM invites WHERE code_hash = ? AND expires_at > ?',
              [sha256Hex(normalizeInviteCode(inviteCode)), _now()],
            );
            if (rows.isEmpty) {
              _ipFailures.fail('ip:$ip');
              throw const ApiError(
                403,
                'invalid_invite',
                'Einladungscode ist ungültig oder abgelaufen',
              );
            }
            inviteId = rows.first['id'] as String;
          case Registration.open:
            break;
        }
      }
      if (_userByName(username) != null) {
        throw const ApiError(
          409,
          'username_taken',
          'Benutzername ist vergeben',
        );
      }
      if (db.select('SELECT 1 FROM users WHERE id = ?', [userId]).isNotEmpty ||
          db.select('SELECT 1 FROM vaults WHERE id = ?', [
            vaultId,
          ]).isNotEmpty) {
        throw const ApiError(409, 'conflict', 'ID bereits vergeben');
      }
      final now = _now();
      db.execute(
        'INSERT INTO users (id, username, is_admin, kdf, salt, auth_hash, '
        'wrapped_user_key, public_key, encrypted_private_key, '
        'recovery_wrapped_user_key, recovery_auth_hash, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          userId,
          username,
          first ? 1 : 0,
          kdf,
          salt,
          sha256Hex(authKey),
          wrappedUserKey,
          publicKey,
          encryptedPrivateKey,
          recoveryWrapped,
          sha256Hex(recoveryAuth),
          now,
          now,
        ],
      );
      db.execute(
        'INSERT INTO vaults (id, owner_id, personal, encrypted_name, created_at) '
        'VALUES (?, ?, 1, ?, ?)',
        [vaultId, userId, vaultName, now],
      );
      db.execute(
        'INSERT INTO vault_members (vault_id, user_id, role, sealed_key, seq, added_at) '
        "VALUES (?, ?, 'owner', ?, ?, ?)",
        [vaultId, userId, sealedKey, _nextSeq(), now],
      );
      if (inviteId != null) {
        db.execute('DELETE FROM invites WHERE id = ?', [inviteId]);
      }
      _audit(
        'register',
        userId: userId,
        username: username,
        detail: first ? 'erster Benutzer, Administrator' : '',
        ip: ip,
      );
      return _createSession(userId, body['device'], request);
    });
    return _json({
      'token': token,
      'account': _accountJson(userId),
    }, status: 201);
  }

  Future<Response> _login(Request request) async {
    final body = await _body(request);
    final username = _str(body, 'username', max: 64).trim();
    final authKey = _str(body, 'authKey', max: 100);
    final user = _verify(
      request,
      username,
      authKey,
      'auth_hash',
      failEvent: 'login_failed',
    );
    final userId = user['id'] as String;
    final token = _createSession(userId, body['device'], request);
    _audit(
      'login',
      userId: userId,
      username: user['username'] as String,
      detail: _deviceLabel(body['device']),
      ip: _ip(request),
    );
    return _json({'token': token, 'account': _accountJson(userId)});
  }

  Future<Response> _recoverStart(Request request) async {
    final body = await _body(request);
    final user = _verify(
      request,
      _str(body, 'username', max: 64).trim(),
      _str(body, 'recoveryAuth', max: 100),
      'recovery_auth_hash',
      failEvent: 'recovery_failed',
    );
    return _json({
      'userId': user['id'],
      'recoveryWrappedUserKey': user['recovery_wrapped_user_key'],
    });
  }

  Future<Response> _recoverFinish(Request request) async {
    final body = await _body(request);
    final user = _verify(
      request,
      _str(body, 'username', max: 64).trim(),
      _str(body, 'recoveryAuth', max: 100),
      'recovery_auth_hash',
      failEvent: 'recovery_failed',
    );
    final userId = user['id'] as String;
    final kdf = _kdf(body['newKdf']);
    final salt = _b64(body, 'newSalt', min: 16, max: 64);
    final authKey = _b64(body, 'newAuthKey', min: 32, max: 32);
    final wrapped = _b64(body, 'newWrappedUserKey', min: 41, max: 200);
    final recoveryWrapped = _b64(
      body,
      'newRecoveryWrappedUserKey',
      min: 41,
      max: 200,
    );
    final recoveryAuth = _b64(body, 'newRecoveryAuth', min: 32, max: 32);
    final token = _transaction(() {
      db.execute(
        'UPDATE users SET kdf = ?, salt = ?, auth_hash = ?, wrapped_user_key = ?, '
        'recovery_wrapped_user_key = ?, recovery_auth_hash = ?, updated_at = ? '
        'WHERE id = ?',
        [
          kdf,
          salt,
          sha256Hex(authKey),
          wrapped,
          recoveryWrapped,
          sha256Hex(recoveryAuth),
          _now(),
          userId,
        ],
      );
      db.execute('DELETE FROM sessions WHERE user_id = ?', [userId]);
      _audit(
        'recovery_used',
        userId: userId,
        username: user['username'] as String,
        detail:
            'Passwort mit Wiederherstellungsschlüssel ersetzt, alle Geräte abgemeldet',
        ip: _ip(request),
      );
      return _createSession(userId, body['device'], request);
    });
    return _json({'token': token, 'account': _accountJson(userId)});
  }
}
