import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import 'backup_check.dart';
import 'config.dart';
import 'landing_page.dart';
import 'security.dart';

part 'server_account.dart';
part 'server_admin.dart';
part 'server_auth.dart';
part 'server_sync.dart';
part 'server_vaults.dart';

const serverVersion = '0.1.5';
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
    this.dataDir,
    this.backupDays = 14,
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

  /// Where nightly database copies go (`<dataDir>/backups`); null = none.
  final String? dataDir;

  /// How many daily copies to keep; 0 switches them off.
  final int backupDays;
  final void Function(String) _log;
  final DateTime Function() _clock;
  late final String _secret;

  static const maxBodyBytes = 256 * 1024;

  /// A key rotation carries every entry of a vault at once.
  static const maxRotateBytes = 24 * 1024 * 1024;
  static const maxEntryBytes = 16 * 1024;
  static const maxContactsBytes = 128 * 1024;
  static const maxEntriesPerVault = 5000;
  static const maxVaultsPerUser = 100;
  static const sessionIdleDays = 180;
  static const maxSessionsPerUser = 50;
  static const auditKeepDays = 365;
  static const trashDays = 30;

  /// Longest wait of a sync request for changes (long poll).
  static const maxSyncWait = Duration(seconds: 30);

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
    r.get('/api/v1/account/contacts', _contacts);
    r.put('/api/v1/account/contacts', _putContacts);
    r.get('/api/v1/sync', _sync);
    r.put('/api/v1/entries/<id>', _putEntry);
    r.delete('/api/v1/entries/<id>', _deleteEntry);
    r.get('/api/v1/trash', _trash);
    r.post('/api/v1/trash/<id>/restore', _restoreEntry);
    r.delete('/api/v1/trash/<id>', _purgeEntry);
    r.post('/api/v1/vaults', _createVault);
    r.patch('/api/v1/vaults/<id>', _renameVault);
    r.delete('/api/v1/vaults/<id>', _deleteVault);
    r.get('/api/v1/vaults/<id>/members', _members);
    r.put('/api/v1/vaults/<id>/members/<userId>', _putMember);
    r.delete('/api/v1/vaults/<id>/members/<userId>', _removeMember);
    r.post('/api/v1/vaults/<id>/rotate', _rotateVault);
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
    // The recycle bin forgets after 30 days; the tombstone stays for sync.
    db.execute(
      "UPDATE entries SET trash_data = '' WHERE deleted = 1 AND trash_data != '' "
      'AND deleted_at < ?',
      [now.subtract(const Duration(days: trashDays)).toIso8601String()],
    );
    backup(now);
  }

  /// One consistent copy of the database per day (`VACUUM INTO`), kept for
  /// [backupDays] days. Encrypted vault data only, but also the accounts:
  /// the folder is readable by the service user alone.
  String? backup([DateTime? at]) {
    final dir = dataDir;
    if (dir == null || backupDays <= 0) return null;
    final now = (at ?? _clock()).toUtc();
    final folder = Directory(p.join(dir, 'backups'))
      ..createSync(recursive: true);
    final day = now.toIso8601String().substring(0, 10);
    final file = File(p.join(folder.path, 'sixora-$day.db'));
    if (!file.existsSync()) {
      try {
        db.execute('VACUUM INTO ?', [file.path]);
      } on SqliteException catch (e) {
        _log('Sicherung fehlgeschlagen: ${e.message}');
        return null;
      }
      // Read it back right away: a copy nobody can open is no backup.
      final check = BackupCheck.inspect(file.path);
      final live = BackupCheck.countsOf(db);
      if (!check.ok ||
          live.entries.any((e) => check.counts[e.key] != e.value)) {
        _log(
          'Sicherung fehlerhaft, verworfen: ${file.path} (${check.describe()}, '
          'erwartet $live)',
        );
        file.deleteSync();
        return null;
      }
      _log('Sicherung: ${file.path} geprüft (${check.describe()})');
    }
    final keepFrom = now.subtract(Duration(days: backupDays));
    for (final old in folder.listSync().whereType<File>()) {
      final match = RegExp(
        r'sixora-(\d{4}-\d{2}-\d{2})\.db$',
      ).firstMatch(old.path);
      final date = match == null
          ? null
          : DateTime.tryParse('${match[1]}T00:00:00Z');
      if (date != null && date.isBefore(keepFrom)) old.deleteSync();
    }
    return file.path;
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

  Future<Map<String, Object?>> _body(
    Request request, {
    int maxBytes = maxBodyBytes,
  }) async {
    final length = request.contentLength;
    if (length != null && length > maxBytes) {
      throw const ApiError(413, 'too_large', 'Anfrage ist zu groß');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in request.read()) {
      bytes.add(chunk);
      if (bytes.length > maxBytes) {
        throw const ApiError(413, 'too_large', 'Anfrage ist zu groß');
      }
    }
    if (bytes.isEmpty) return {};
    final json = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (json is! Map) throw const FormatException('JSON-Objekt erwartet');
    return json.cast();
  }

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
    // Waiting sync requests wake up once the change is committed (the
    // transaction finishes synchronously before microtasks run).
    scheduleMicrotask(_changed.notifyListeners);
    return _currentSeq();
  }

  final _changed = _ChangeSignal();

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
    // Other devices learn about the new sign-in with their waiting sync.
    _nextSeq();
    return token;
  }

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
}

/// Wakes up waiting sync requests when anything changed.
class _ChangeSignal {
  Completer<void> _next = Completer<void>();

  Future<void> get next => _next.future;

  void notifyListeners() {
    final done = _next;
    _next = Completer<void>();
    done.complete();
  }
}

// --- Helpers shared by all parts -------------------------------------------

Response _json(Object body, {int status = 200}) => Response(
  status,
  body: jsonEncode(body),
  headers: {'Content-Type': 'application/json; charset=utf-8'},
);

Response _error(int status, String code, String message) =>
    _json({'error': code, 'message': message}, status: status);

Response _ok() => _json({'ok': true});

String _str(
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
String _b64(
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

String _uuid(Object? v, String what) {
  if (v is String && uuidPattern.hasMatch(v)) return v;
  throw FormatException('$what ist ungültig');
}

/// Same bounds as the clients enforce.
String _kdf(Object? v) {
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

final _usernamePattern = RegExp(
  r'^[A-Za-z0-9][A-Za-z0-9._@+-]{1,62}[A-Za-z0-9]$',
);

String _clip(String s, int max) => s.length <= max ? s : s.substring(0, max);

String _deviceLabel(Object? device) => device is Map
    ? _clip('${device['name'] ?? ''} (${device['platform'] ?? ''})', 120)
    : '';

Response _auditJson(ResultSet rows) => _json({
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

Map<String, Object?> _entryJson(Row r) => {
  'id': r['id'],
  'vaultId': r['vault_id'],
  'revision': r['revision'],
  'deleted': r['deleted'] == 1,
  'data': r['data'],
  'updatedAt': r['updated_at'],
};
