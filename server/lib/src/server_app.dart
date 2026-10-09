import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import 'config.dart';
import 'landing_page.dart';
import 'security.dart';

const serverVersion = '0.1.2';
const apiVersion = 1;

/// Error answered as `{"error": code, "message": text}`.
class ApiError implements Exception {
  const ApiError(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;
}

class _Session {
  _Session(this.id, this.userId, this.username, this.isAdmin);
  final String id;
  final String userId;
  final String username;
  final bool isAdmin;
}

/// The HTTP API of the Sixora server.
///
/// The server is a dumb, careful store: it authenticates devices, keeps the
/// encrypted vault blobs with revisions, and enforces who may read and
/// write which vault. It cannot decrypt anything.
class SixoraServerApp {
  SixoraServerApp({
    required this.db,
    required this.registration,
    this.serverName = 'Sixora',
    this.trustProxy = false,
    this.tls = false,
    void Function(String line)? log,
    DateTime Function()? clock,
  }) : _log = log ?? ((_) {}),
       _clock = clock ?? DateTime.now {
    _secret = _loadSecret();
  }

  final Database db;
  final Registration registration;
  final String serverName;
  final bool trustProxy;
  final bool tls;
  final void Function(String) _log;
  final DateTime Function() _clock;
  late final String _secret;

  static const maxBodyBytes = 256 * 1024;
  static const maxEntryBytes = 16 * 1024;
  static const maxEntriesPerVault = 5000;
  static const maxVaultsPerUser = 100;
  static const sessionIdleDays = 180;
  static const maxSessionsPerUser = 50;
  static const auditKeepDays = 365;

  final _userFailures = FailureLimiter(
    max: 10,
    window: const Duration(minutes: 15),
  );
  final _ipFailures = FailureLimiter(
    max: 30,
    window: const Duration(minutes: 15),
  );
  // Coarse abuse guard. Behind a reverse proxy without SIXORA_TRUST_PROXY all
  // clients share one address, hence the generous limit.
  final _ipRequests = FailureLimiter(
    max: 1200,
    window: const Duration(minutes: 1),
  );
  Timer? _maintenance;

  String _now() => _clock().toUtc().toIso8601String();

  late final Handler handler = const Pipeline()
      .addMiddleware(_errors)
      .addMiddleware(_headers)
      .addHandler(_router.call);

  Router get _router {
    final r = Router(
      notFoundHandler: (_) => _error(404, 'not_found', 'Nicht gefunden'),
    );
    r.get('/', _root);
    r.get('/robots.txt', _robots);
    r.get('/api/v1/info', _info);
    r.post('/api/v1/auth/prelogin', _prelogin);
    r.post('/api/v1/auth/register', _register);
    r.post('/api/v1/auth/login', _login);
    r.post('/api/v1/auth/recover/start', _recoverStart);
    r.post('/api/v1/auth/recover/finish', _recoverFinish);
    r.post('/api/v1/auth/logout', _logout);
    r.get('/api/v1/account', _account);
    r.post('/api/v1/account/password', _changePassword);
    r.post('/api/v1/account/recovery', _setRecovery);
    r.post('/api/v1/account/delete', _deleteAccount);
    r.get('/api/v1/account/sessions', _sessions);
    r.delete('/api/v1/account/sessions/<id>', _revokeSession);
    r.get('/api/v1/account/audit', _accountAudit);
    r.get('/api/v1/sync', _sync);
    r.put('/api/v1/entries/<id>', _putEntry);
    r.delete('/api/v1/entries/<id>', _deleteEntry);
    r.post('/api/v1/vaults', _createVault);
    r.patch('/api/v1/vaults/<id>', _renameVault);
    r.delete('/api/v1/vaults/<id>', _deleteVault);
    r.get('/api/v1/vaults/<id>/members', _members);
    r.put('/api/v1/vaults/<id>/members/<userId>', _putMember);
    r.delete('/api/v1/vaults/<id>/members/<userId>', _removeMember);
    r.get('/api/v1/users/lookup', _lookupUser);
    r.get('/api/v1/admin/users', _adminUsers);
    r.patch('/api/v1/admin/users/<id>', _adminUpdateUser);
    r.delete('/api/v1/admin/users/<id>', _adminDeleteUser);
    r.get('/api/v1/admin/invites', _adminInvites);
    r.post('/api/v1/admin/invites', _adminCreateInvite);
    r.delete('/api/v1/admin/invites/<id>', _adminDeleteInvite);
    r.get('/api/v1/admin/audit', _adminAudit);
    return r;
  }

  void startMaintenance() {
    _maintenance ??= Timer.periodic(
      const Duration(hours: 6),
      (_) => maintain(),
    );
    maintain();
  }

  void close() => _maintenance?.cancel();

  /// Removes idle sessions, expired invites, old audit entries and
  /// tombstones of deleted entries that every device has long seen.
  void maintain() {
    final now = _clock().toUtc();
    db.execute('DELETE FROM sessions WHERE last_seen_at < ?', [
      now.subtract(const Duration(days: sessionIdleDays)).toIso8601String(),
    ]);
    db.execute('DELETE FROM invites WHERE expires_at < ?', [
      now.toIso8601String(),
    ]);
    db.execute('DELETE FROM audit WHERE at < ?', [
      now.subtract(const Duration(days: auditKeepDays)).toIso8601String(),
    ]);
  }

  // --- Middleware ------------------------------------------------------------

  Handler _errors(Handler inner) => (request) async {
    try {
      if (_ipRequests.blocked('req:${_ip(request)}')) {
        throw const ApiError(429, 'rate_limited', 'Zu viele Anfragen');
      }
      _ipRequests.fail('req:${_ip(request)}');
      return await inner(request);
    } on ApiError catch (e) {
      return _error(e.status, e.code, e.message);
    } on FormatException catch (e) {
      return _error(400, 'bad_request', e.message);
    } on TypeError {
      return _error(400, 'bad_request', 'Ungültige Anfrage');
    } on SqliteException catch (e) {
      _log('DB-Fehler: ${e.message}');
      return _error(500, 'internal', 'Interner Fehler');
    }
  };

  Handler _headers(Handler inner) => (request) async {
    final response = await inner(request);
    return response.change(
      headers: {
        'Cache-Control': 'no-store',
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
        'Referrer-Policy': 'no-referrer',
        // The landing page brings its own, slightly wider policy.
        'Content-Security-Policy':
            response.headers['content-security-policy'] ??
            "default-src 'none'; frame-ancestors 'none'",
        'Permissions-Policy':
            'camera=(), microphone=(), geolocation=(), payment=(), usb=()',
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Resource-Policy': 'same-origin',
        'X-Robots-Tag': 'noindex, nofollow',
        if (tls) 'Strict-Transport-Security': 'max-age=31536000',
      },
    );
  };

  static Response _json(Object body, {int status = 200}) => Response(
    status,
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json; charset=utf-8'},
  );

  static Response _error(int status, String code, String message) =>
      _json({'error': code, 'message': message}, status: status);

  static Response _ok() => _json({'ok': true});

  /// Client address for rate limits and the audit log. Behind a trusted
  /// proxy it is the address the proxy itself saw: X-Real-IP, or the last
  /// X-Forwarded-For entry. Earlier entries come from the client and can be
  /// forged to dodge the login limits.
  String _ip(Request request) {
    if (trustProxy) {
      final real = request.headers['x-real-ip']?.trim();
      if (real != null && real.isNotEmpty) return real;
      final fwd = request.headers['x-forwarded-for'];
      if (fwd != null && fwd.trim().isNotEmpty) {
        return fwd.split(',').last.trim();
      }
    }
    final info = request.context['shelf.io.connection_info'];
    return info is HttpConnectionInfo ? info.remoteAddress.address : '';
  }

  Future<Map<String, Object?>> _body(Request request) async {
    final length = request.contentLength;
    if (length != null && length > maxBodyBytes) {
      throw const ApiError(413, 'too_large', 'Anfrage ist zu groß');
    }
    final bytes = <int>[];
    await for (final chunk in request.read()) {
      bytes.addAll(chunk);
      if (bytes.length > maxBodyBytes) {
        throw const ApiError(413, 'too_large', 'Anfrage ist zu groß');
      }
    }
    if (bytes.isEmpty) return {};
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map) throw const FormatException('JSON-Objekt erwartet');
    return json.cast();
  }

  static String _str(
    Map<String, Object?> body,
    String key, {
    int max = 200,
    bool required = true,
  }) {
    final v = body[key];
    if (v == null && !required) return '';
    if (v is! String || (required && v.isEmpty) || v.length > max) {
      throw FormatException('Feld „$key“ fehlt oder ist ungültig');
    }
    return v;
  }

  /// Base64 field with a decoded length between [min] and [max] bytes.
  static String _b64(
    Map<String, Object?> body,
    String key, {
    int min = 16,
    int max = 4096,
  }) {
    final v = _str(body, key, max: max * 2);
    try {
      final len = base64.decode(v).length;
      if (len >= min && len <= max) return v;
    } on FormatException {
      // handled below
    }
    throw FormatException('Feld „$key“ ist ungültig');
  }

  static String _uuid(Object? v, String what) {
    if (v is String && uuidPattern.hasMatch(v)) return v;
    throw FormatException('$what ist ungültig');
  }

  /// Same bounds as the clients enforce.
  static String _kdf(Object? v) {
    if (v is! Map) throw const FormatException('kdf fehlt');
    final m = v['m'], t = v['t'], p = v['p'];
    if (v['alg'] != 'argon2id' ||
        m is! int ||
        t is! int ||
        p is! int ||
        m < 19456 ||
        m > 1048576 ||
        t < 2 ||
        t > 20 ||
        p < 1 ||
        p > 8) {
      throw const FormatException('kdf ist ungültig');
    }
    return jsonEncode({'alg': 'argon2id', 'm': m, 't': t, 'p': p});
  }

  static final _usernamePattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._@+-]{1,62}[A-Za-z0-9]$',
  );

  void _audit(
    String event, {
    String userId = '',
    String username = '',
    String detail = '',
    String ip = '',
  }) {
    db.execute(
      'INSERT INTO audit (at, user_id, username, event, detail, ip) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [_now(), userId, username, event, detail, ip],
    );
    _log('audit $event user=$username${detail.isEmpty ? '' : ' $detail'}');
  }

  T _transaction<T>(T Function() action) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = action();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  int _nextSeq() {
    db.execute(
      "UPDATE meta SET value = CAST(value AS INTEGER) + 1 WHERE key = 'seq'",
    );
    return _currentSeq();
  }

  int _currentSeq() => int.parse(
    db.select("SELECT value FROM meta WHERE key = 'seq'").first['value']
        as String,
  );

  String _loadSecret() {
    final rows = db.select("SELECT value FROM meta WHERE key = 'secret'");
    if (rows.isNotEmpty) return rows.first['value'] as String;
    final secret = base64.encode(randomBytes(32));
    db.execute("INSERT INTO meta (key, value) VALUES ('secret', ?)", [secret]);
    return secret;
  }

  // --- Sessions --------------------------------------------------------------

  _Session _auth(Request request) {
    final header = request.headers['authorization'] ?? '';
    if (!header.startsWith('Bearer ')) {
      throw const ApiError(401, 'unauthorized', 'Nicht angemeldet');
    }
    final hash = sha256Hex(header.substring(7).trim());
    final rows = db.select(
      'SELECT s.id, s.user_id, s.last_seen_at, u.username, u.is_admin, u.disabled '
      'FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = ?',
      [hash],
    );
    if (rows.isEmpty) {
      throw const ApiError(401, 'unauthorized', 'Sitzung ist abgelaufen');
    }
    final row = rows.first;
    if (row['disabled'] == 1) {
      throw const ApiError(401, 'disabled', 'Konto ist gesperrt');
    }
    final lastSeen = DateTime.parse(row['last_seen_at'] as String);
    final now = _clock().toUtc();
    if (now.difference(lastSeen).inDays >= sessionIdleDays) {
      db.execute('DELETE FROM sessions WHERE id = ?', [row['id']]);
      throw const ApiError(401, 'unauthorized', 'Sitzung ist abgelaufen');
    }
    if (now.difference(lastSeen).inMinutes >= 5) {
      db.execute('UPDATE sessions SET last_seen_at = ?, ip = ? WHERE id = ?', [
        now.toIso8601String(),
        _ip(request),
        row['id'],
      ]);
    }
    return _Session(
      row['id'] as String,
      row['user_id'] as String,
      row['username'] as String,
      row['is_admin'] == 1,
    );
  }

  _Session _admin(Request request) {
    final s = _auth(request);
    if (!s.isAdmin) {
      throw const ApiError(403, 'forbidden', 'Nur für Administratoren');
    }
    return s;
  }

  String _createSession(String userId, Object? device, Request request) {
    final d = device is Map ? device.cast<String, Object?>() : const {};
    final name = (d['name'] is String ? d['name'] as String : '').trim();
    final platform = (d['platform'] is String ? d['platform'] as String : '')
        .trim();
    final token = newToken();
    db.execute(
      'INSERT INTO sessions (id, user_id, token_hash, device_name, platform, '
      'created_at, last_seen_at, ip) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        newUuid(),
        userId,
        sha256Hex(token),
        name.isEmpty ? 'Unbekanntes Gerät' : _clip(name, 80),
        _clip(platform, 30),
        _now(),
        _now(),
        _ip(request),
      ],
    );
    // Bounded per account: the oldest sessions give way.
    db.execute(
      'DELETE FROM sessions WHERE user_id = ? AND id NOT IN '
      '(SELECT id FROM sessions WHERE user_id = ? '
      'ORDER BY last_seen_at DESC, created_at DESC LIMIT ?)',
      [userId, userId, maxSessionsPerUser],
    );
    return token;
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  Map<String, Object?> _accountJson(String userId) {
    final u = db.select('SELECT * FROM users WHERE id = ?', [userId]).first;
    return {
      'id': u['id'],
      'username': u['username'],
      'isAdmin': u['is_admin'] == 1,
      'kdf': jsonDecode(u['kdf'] as String),
      'salt': u['salt'],
      'wrappedUserKey': u['wrapped_user_key'],
      'publicKey': u['public_key'],
      'encryptedPrivateKey': u['encrypted_private_key'],
    };
  }

  Row? _userByName(String username) {
    final rows = db.select('SELECT * FROM users WHERE username = ?', [
      username,
    ]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Checks a secret against its stored SHA-256 hash and applies the
  /// brute-force limits per user name and IP.
  Row _verify(
    Request request,
    String username,
    String secret,
    String column, {
    required String failEvent,
  }) {
    final ip = _ip(request);
    final userKey = 'user:${username.toLowerCase()}';
    if (_userFailures.blocked(userKey) || _ipFailures.blocked('ip:$ip')) {
      throw const ApiError(
        429,
        'rate_limited',
        'Zu viele Fehlversuche. Bitte in 15 Minuten erneut versuchen.',
      );
    }
    final user = _userByName(username);
    final hash = sha256Hex(secret);
    if (user == null || !constantTimeEquals(hash, user[column] as String)) {
      _userFailures.fail(userKey);
      _ipFailures.fail('ip:$ip');
      if (user != null) {
        _audit(
          failEvent,
          userId: user['id'] as String,
          username: user['username'] as String,
          ip: ip,
        );
      } else {
        // Shows up in the admin log: guessing of user names.
        _audit(
          failEvent,
          detail: 'unbekannter Benutzer „${_clip(username, 64)}“',
          ip: ip,
        );
      }
      throw const ApiError(
        401,
        'invalid_credentials',
        'Benutzername oder Passwort ist falsch',
      );
    }
    if (user['disabled'] == 1) {
      throw const ApiError(403, 'disabled', 'Konto ist gesperrt');
    }
    _userFailures.reset(userKey);
    return user;
  }

  /// Re-checks the master password for sensitive account changes.
  void _verifyCurrent(_Session s, Request request, String authKey) => _verify(
    request,
    s.username,
    authKey,
    'auth_hash',
    failEvent: 'reauth_failed',
  );

  // --- Public endpoints ----------------------------------------------------

  late final _landing = LandingPage(serverName);

  Response _root(Request request) {
    final uri = request.requestedUri;
    final proto = trustProxy
        ? request.headers['x-forwarded-proto']?.split(',').first.trim()
        : null;
    final scheme = proto == 'https' || tls ? 'https' : uri.scheme;
    final defaultPort =
        uri.port == (scheme == 'https' ? 443 : 80) || proto != null;
    final address = '$scheme://${uri.host}${defaultPort ? '' : ':${uri.port}'}';
    return Response.ok(
      _landing.render(address: address),
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'Content-Security-Policy': LandingPage.contentSecurityPolicy,
      },
    );
  }

  Response _robots(Request request) => Response.ok(
    'User-agent: *\nDisallow: /\n',
    headers: {'Content-Type': 'text/plain; charset=utf-8'},
  );

  bool get _hasUsers => db.select('SELECT 1 FROM users LIMIT 1').isNotEmpty;

  Response _info(Request request) => _json({
    'name': serverName,
    'version': serverVersion,
    'apiVersion': apiVersion,
    'registration': registration.name,
    'hasUsers': _hasUsers,
  });

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

  static String _deviceLabel(Object? device) => device is Map
      ? _clip('${device['name'] ?? ''} (${device['platform'] ?? ''})', 120)
      : '';

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

  // --- Account ---------------------------------------------------------------

  Response _logout(Request request) {
    final s = _auth(request);
    db.execute('DELETE FROM sessions WHERE id = ?', [s.id]);
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
      db.execute('DELETE FROM users WHERE id = ?', [s.userId]);
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

  static Response _auditJson(ResultSet rows) => _json({
    'events': [
      for (final r in rows)
        {
          'at': r['at'],
          'event': r['event'],
          'detail': r['detail'],
          'username': r['username'],
          'ip': r['ip'],
        },
    ],
  });

  // --- Vault data ------------------------------------------------------------

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

  Response _sync(Request request) {
    final s = _auth(request);
    final since =
        int.tryParse(request.url.queryParameters['since'] ?? '0') ?? 0;
    final cursor = _currentSeq();
    final vaults = db.select(
      'SELECT v.id, v.personal, v.owner_id, v.encrypted_name, o.username AS owner_name, '
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
          },
      ],
      'entries': entries,
    });
  }

  static Map<String, Object?> _entryJson(Row r) => {
    'id': r['id'],
    'vaultId': r['vault_id'],
    'revision': r['revision'],
    'deleted': r['deleted'] == 1,
    'data': r['data'],
    'updatedAt': r['updated_at'],
  };

  Future<Response> _putEntry(Request request, String id) async {
    final s = _auth(request);
    _uuid(id, 'Eintrags-ID');
    final body = await _body(request);
    final vaultId = _uuid(body['vaultId'], 'Tresor-ID');
    final data = _b64(body, 'data', min: 41, max: maxEntryBytes);
    final base = body['baseRevision'];
    if (base is! int || base < 0) {
      throw const FormatException('baseRevision fehlt');
    }
    final row = _transaction(() {
      _requireMember(vaultId, s.userId, write: true);
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
        if (count >= maxEntriesPerVault) {
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
          'updated_at = ?, updated_by = ? WHERE id = ?',
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
      db.execute(
        "UPDATE entries SET data = '', revision = revision + 1, deleted = 1, seq = ?, "
        'updated_at = ?, updated_by = ? WHERE id = ?',
        [_nextSeq(), _now(), s.userId, id],
      );
      return db.select('SELECT * FROM entries WHERE id = ?', [id]).first;
    });
    return _json(_entryJson(row));
  }

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
      if (count >= maxVaultsPerUser) {
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
    _requireMember(id, s.userId, owner: true);
    _transaction(() {
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

  // --- Administration ------------------------------------------------------

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

  /// Also used by the `invite` command line.
  Map<String, Object?> createInvite({
    int days = 7,
    String note = '',
    String createdBy = '',
  }) {
    final code = newInviteCode();
    final id = newUuid();
    final now = _clock().toUtc();
    final expires = now.add(Duration(days: days)).toIso8601String();
    db.execute(
      'INSERT INTO invites (id, code_hash, note, created_by, created_at, expires_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        id,
        sha256Hex(normalizeInviteCode(code)),
        note,
        createdBy,
        now.toIso8601String(),
        expires,
      ],
    );
    return {
      'id': id,
      'code': code,
      'note': note,
      'createdAt': now.toIso8601String(),
      'expiresAt': expires,
    };
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
