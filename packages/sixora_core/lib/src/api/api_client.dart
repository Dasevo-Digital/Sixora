import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../platform/transport_io.dart'
    if (dart.library.js_interop) '../platform/transport_web.dart';
import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message);

  /// HTTP status; 0 when the server could not be reached.
  final int status;

  /// Machine readable error code from the server, e.g. `conflict`.
  final String code;
  final String message;

  bool get offline => status == 0;
  bool get unauthorized => status == 401;
  bool get conflict => status == 409;

  @override
  String toString() => message;
}

/// Thin HTTP client for the Sixora server API.
class SixoraApi {
  SixoraApi(Uri baseUrl, {this.token, http.Client? client})
    : baseUrl = normalizeBaseUrl(baseUrl),
      _client = client ?? http.Client();

  static const apiVersion = 1;
  static const _timeout = Duration(seconds: 20);

  final Uri baseUrl;
  String? token;
  final http.Client _client;

  /// Adds a scheme (https) and a trailing slash.
  static Uri normalizeBaseUrl(Uri url) {
    var u = url;
    if (!u.hasScheme) u = Uri.parse('https://$url');
    final path = u.path.endsWith('/') ? u.path : '${u.path}/';
    // Rebuilt without query and fragment ("replace(query: '')" would keep
    // a dangling "?").
    return Uri(
      scheme: u.scheme,
      host: u.host,
      port: u.hasPort ? u.port : null,
      path: path,
    );
  }

  /// True for loopback and private network addresses, where plain HTTP is
  /// tolerated (with a warning in the app).
  static bool isLocalHost(String host) {
    if (host == 'localhost' || host.endsWith('.local')) return true;
    // Without dart:io, so it also works in the browser extension.
    final v4 = _tryParse(Uri.parseIPv4Address, host);
    if (v4 != null) {
      return v4[0] == 127 ||
          v4[0] == 10 ||
          (v4[0] == 169 && v4[1] == 254) ||
          (v4[0] == 172 && v4[1] >= 16 && v4[1] < 32) ||
          (v4[0] == 192 && v4[1] == 168);
    }
    final v6 = _tryParse(
      Uri.parseIPv6Address,
      host.startsWith('[') ? host.substring(1, host.length - 1) : host,
    );
    if (v6 == null) return false;
    final loopback =
        v6.sublist(0, 15).every((b) => b == 0) && v6[15] == 1; // ::1
    return loopback ||
        (v6[0] == 0xfe && (v6[1] & 0xc0) == 0x80) || // fe80::/10
        (v6[0] & 0xfe) == 0xfc; // fc00::/7
  }

  static List<int>? _tryParse(List<int> Function(String) parse, String s) {
    try {
      return parse(s);
    } on FormatException {
      return null;
    }
  }

  void close() => _client.close();

  Future<Object?> _send(
    String method,
    String path, {
    Duration timeout = _timeout,
    Object? body,
    Map<String, String>? query,
  }) async {
    var uri = baseUrl.resolve('api/v1/$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(0, 'offline', 'Server antwortet nicht');
    } on http.ClientException catch (e) {
      // dart:io reports DNS problems as a socket error inside it.
      throw transportError(e, uri) ??
          ApiException(0, 'offline', 'Server nicht erreichbar: ${e.message}');
    } on Exception catch (e) {
      throw transportError(e, uri) ?? e;
    }
    Object? json;
    if (response.body.isNotEmpty) {
      try {
        json = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        json = null;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    final map = json is Map ? json : const {};
    throw ApiException(
      response.statusCode,
      map['error'] as String? ?? 'http_${response.statusCode}',
      map['message'] as String? ??
          (json == null && response.statusCode != 401
              ? 'Unerwartete Antwort – ist das ein Sixora-Server?'
              : 'Fehler ${response.statusCode}'),
    );
  }

  Future<Map<String, Object?>> _map(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Duration timeout = _timeout,
  }) async =>
      ((await _send(method, path, body: body, query: query, timeout: timeout))
                  as Map? ??
              {})
          .cast();

  Future<List<Map<String, Object?>>> _list(
    String path,
    String key, {
    Map<String, String>? query,
  }) async {
    final m = await _map('GET', path, query: query);
    return [for (final e in m[key] as List? ?? const []) (e as Map).cast()];
  }
  // --- Public ----------------------------------------------------------------

  Future<ServerInfo> info() async {
    final info = ServerInfo.fromJson(await _map('GET', 'info'));
    if (info.apiVersion != apiVersion) {
      throw ApiException(
        0,
        'version',
        'Server-Version ${info.version} passt nicht zu dieser App',
      );
    }
    return info;
  }

  Future<({Map<String, Object?> kdf, String salt})> prelogin(
    String username,
  ) async {
    final m = await _map('POST', 'auth/prelogin', body: {'username': username});
    return (
      kdf: (m['kdf'] as Map).cast<String, Object?>(),
      salt: m['salt'] as String,
    );
  }

  Future<LoginResult> register(Map<String, Object?> body) async {
    final r = LoginResult.fromJson(
      await _map('POST', 'auth/register', body: body),
    );
    token = r.token;
    return r;
  }

  Future<LoginResult> login({
    required String username,
    required String authKey,
    required DeviceInfo device,
  }) async {
    final r = LoginResult.fromJson(
      await _map(
        'POST',
        'auth/login',
        body: {
          'username': username,
          'authKey': authKey,
          'device': device.toJson(),
        },
      ),
    );
    token = r.token;
    return r;
  }

  /// First step of a password reset with the recovery key: returns the user
  /// key wrapped with the recovery key.
  Future<({String userId, String recoveryWrappedUserKey})> recoverStart({
    required String username,
    required String recoveryAuth,
  }) async {
    final m = await _map(
      'POST',
      'auth/recover/start',
      body: {'username': username, 'recoveryAuth': recoveryAuth},
    );
    return (
      userId: m['userId'] as String,
      recoveryWrappedUserKey: m['recoveryWrappedUserKey'] as String,
    );
  }

  Future<LoginResult> recoverFinish(Map<String, Object?> body) async {
    final r = LoginResult.fromJson(
      await _map('POST', 'auth/recover/finish', body: body),
    );
    token = r.token;
    return r;
  }

  // --- Account -------------------------------------------------------------

  Future<void> logout() async {
    await _send('POST', 'auth/logout');
    token = null;
  }

  Future<AccountBundle> account() async =>
      AccountBundle.fromJson(await _map('GET', 'account'));

  Future<void> changePassword(Map<String, Object?> body) =>
      _send('POST', 'account/password', body: body);

  Future<void> setRecoveryKey({
    required String authKey,
    required String recoveryWrappedUserKey,
    required String recoveryAuth,
  }) => _send(
    'POST',
    'account/recovery',
    body: {
      'authKey': authKey,
      'recoveryWrappedUserKey': recoveryWrappedUserKey,
      'recoveryAuth': recoveryAuth,
    },
  );

  Future<void> deleteAccount(String authKey) =>
      _send('POST', 'account/delete', body: {'authKey': authKey});

  Future<List<SessionDto>> sessions() async => [
    for (final s in await _list('account/sessions', 'sessions'))
      SessionDto.fromJson(s),
  ];

  Future<void> revokeSession(String id) =>
      _send('DELETE', 'account/sessions/$id');

  /// The encrypted trusted keys (see `TrustedKeys`); empty data at first.
  Future<({String data, int revision})> contacts() async {
    final m = await _map('GET', 'account/contacts');
    return (
      data: m['data'] as String? ?? '',
      revision: (m['revision'] as num?)?.toInt() ?? 0,
    );
  }

  /// Returns the new revision; a 409 means another device was faster.
  Future<int> putContacts(String data, {required int baseRevision}) async =>
      ((await _map(
                'PUT',
                'account/contacts',
                body: {'data': data, 'baseRevision': baseRevision},
              ))['revision']
              as num)
          .toInt();

  Future<List<AuditDto>> accountAudit() async => [
    for (final a in await _list('account/audit', 'events'))
      AuditDto.fromJson(a),
  ];

  // --- Vault data ----------------------------------------------------------

  /// Changes since [since]. With [wait] the server holds the request until
  /// something changes (at most [wait]), so changes from other devices
  /// arrive at once.
  Future<SyncResult> sync(int since, {Duration? wait}) async =>
      SyncResult.fromJson(
        await _map(
          'GET',
          'sync',
          query: {
            'since': '$since',
            if (wait != null) 'wait': '${wait.inSeconds}',
          },
          timeout: wait == null ? _timeout : wait + _timeout,
        ),
      );

  /// Deleted entries of the last 30 days, still encrypted.
  Future<List<EntryDto>> trash() async => [
    for (final e in await _list('trash', 'entries')) EntryDto.fromJson(e),
  ];

  Future<EntryDto> restoreEntry(String id) async =>
      EntryDto.fromJson(await _map('POST', 'trash/$id/restore'));

  Future<void> purgeEntry(String id) => _send('DELETE', 'trash/$id');

  /// Creates or updates an entry. [baseRevision] is the revision the change
  /// is based on (0 for new entries); a mismatch gives a 409 conflict.
  Future<EntryDto> putEntry({
    required String id,
    required String vaultId,
    required String data,
    required int baseRevision,
    int? keyVersion,
  }) async => EntryDto.fromJson(
    await _map(
      'PUT',
      'entries/$id',
      body: {
        'vaultId': vaultId,
        'data': data,
        'baseRevision': baseRevision,
        'keyVersion': ?keyVersion,
      },
    ),
  );

  Future<EntryDto> deleteEntry(String id, {required int baseRevision}) async =>
      EntryDto.fromJson(
        await _map(
          'DELETE',
          'entries/$id',
          query: {'baseRevision': '$baseRevision'},
        ),
      );

  Future<void> createVault({
    required String id,
    required String encryptedName,
    required String sealedKey,
  }) => _send(
    'POST',
    'vaults',
    body: {'id': id, 'encryptedName': encryptedName, 'sealedKey': sealedKey},
  );

  Future<void> renameVault(
    String id,
    String encryptedName, {
    int? keyVersion,
  }) => _send(
    'PATCH',
    'vaults/$id',
    body: {'encryptedName': encryptedName, 'keyVersion': ?keyVersion},
  );

  /// Replaces the vault key; [body] comes from `rotateVaultKey`.
  Future<void> rotateVault(String id, Map<String, Object?> body) => _send(
    'POST',
    'vaults/$id/rotate',
    body: body,
    timeout: const Duration(minutes: 2),
  );

  Future<void> deleteVault(String id) => _send('DELETE', 'vaults/$id');

  Future<List<MemberDto>> members(String vaultId) async => [
    for (final m in await _list('vaults/$vaultId/members', 'members'))
      MemberDto.fromJson(m),
  ];

  Future<void> addMember(
    String vaultId, {
    required String userId,
    required String sealedKey,
    required VaultRole role,
  }) => _send(
    'PUT',
    'vaults/$vaultId/members/$userId',
    body: {'sealedKey': sealedKey, 'role': role.name},
  );

  Future<void> removeMember(String vaultId, String userId) =>
      _send('DELETE', 'vaults/$vaultId/members/$userId');

  Future<UserDto> lookupUser(String username) async => UserDto.fromJson(
    await _map('GET', 'users/lookup', query: {'username': username}),
  );

  // --- Administration ------------------------------------------------------

  Future<List<UserDto>> adminUsers() async => [
    for (final u in await _list('admin/users', 'users')) UserDto.fromJson(u),
  ];

  Future<void> adminUpdateUser(String id, {bool? disabled, bool? isAdmin}) =>
      _send(
        'PATCH',
        'admin/users/$id',
        body: {'disabled': ?disabled, 'isAdmin': ?isAdmin},
      );

  Future<void> adminDeleteUser(String id) => _send('DELETE', 'admin/users/$id');

  Future<List<InviteDto>> adminInvites() async => [
    for (final i in await _list('admin/invites', 'invites'))
      InviteDto.fromJson(i),
  ];

  Future<InviteDto> adminCreateInvite({String note = '', int days = 7}) async =>
      InviteDto.fromJson(
        await _map('POST', 'admin/invites', body: {'note': note, 'days': days}),
      );

  Future<void> adminDeleteInvite(String id) =>
      _send('DELETE', 'admin/invites/$id');

  Future<List<AuditDto>> adminAudit() async => [
    for (final a in await _list('admin/audit', 'events')) AuditDto.fromJson(a),
  ];
}
