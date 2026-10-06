/// Wire models of the Sixora server API (`/api/v1`). Everything secret in
/// here is ciphertext; the server never sees an OTP secret or a key.
library;

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

enum RegistrationMode {
  open,
  invite,
  closed;

  static RegistrationMode parse(Object? v) => switch (v) {
    'open' => open,
    'closed' => closed,
    _ => invite,
  };
}

class ServerInfo {
  const ServerInfo({
    required this.name,
    required this.version,
    required this.apiVersion,
    required this.registration,
    required this.hasUsers,
  });
  final String name;
  final String version;
  final int apiVersion;
  final RegistrationMode registration;

  /// False until the first account (the administrator) exists.
  final bool hasUsers;

  factory ServerInfo.fromJson(Map<String, Object?> j) => ServerInfo(
    name: j['name'] as String? ?? 'Sixora',
    version: j['version'] as String? ?? '',
    apiVersion: (j['apiVersion'] as num?)?.toInt() ?? 0,
    registration: RegistrationMode.parse(j['registration']),
    hasUsers: j['hasUsers'] as bool? ?? true,
  );
}

class DeviceInfo {
  const DeviceInfo({required this.name, required this.platform});
  final String name;
  final String platform;
  Map<String, Object?> toJson() => {'name': name, 'platform': platform};
}

/// The account's key material as stored on the server.
class AccountBundle {
  const AccountBundle({
    required this.id,
    required this.username,
    required this.isAdmin,
    required this.kdf,
    required this.salt,
    required this.wrappedUserKey,
    required this.publicKey,
    required this.encryptedPrivateKey,
  });
  final String id;
  final String username;
  final bool isAdmin;
  final Map<String, Object?> kdf;
  final String salt;
  final String wrappedUserKey;
  final String publicKey;
  final String encryptedPrivateKey;

  factory AccountBundle.fromJson(Map<String, Object?> j) => AccountBundle(
    id: j['id'] as String,
    username: j['username'] as String,
    isAdmin: j['isAdmin'] as bool? ?? false,
    kdf: (j['kdf'] as Map).cast<String, Object?>(),
    salt: j['salt'] as String,
    wrappedUserKey: j['wrappedUserKey'] as String,
    publicKey: j['publicKey'] as String,
    encryptedPrivateKey: j['encryptedPrivateKey'] as String,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'isAdmin': isAdmin,
    'kdf': kdf,
    'salt': salt,
    'wrappedUserKey': wrappedUserKey,
    'publicKey': publicKey,
    'encryptedPrivateKey': encryptedPrivateKey,
  };
}

class LoginResult {
  const LoginResult({required this.token, required this.account});
  final String token;
  final AccountBundle account;
  factory LoginResult.fromJson(Map<String, Object?> j) => LoginResult(
    token: j['token'] as String,
    account: AccountBundle.fromJson((j['account'] as Map).cast()),
  );
}

enum VaultRole {
  owner,
  write,
  read;

  static VaultRole parse(Object? v) => switch (v) {
    'owner' => owner,
    'write' => write,
    _ => read,
  };

  bool get canWrite => this != read;
}

class VaultDto {
  const VaultDto({
    required this.id,
    required this.personal,
    required this.ownerId,
    required this.ownerName,
    required this.role,
    required this.encryptedName,
    required this.sealedKey,
    required this.memberCount,
  });
  final String id;
  final bool personal;
  final String ownerId;
  final String ownerName;
  final VaultRole role;
  final String encryptedName;

  /// The vault key, sealed to this user's public key.
  final String sealedKey;
  final int memberCount;

  factory VaultDto.fromJson(Map<String, Object?> j) => VaultDto(
    id: j['id'] as String,
    personal: j['personal'] as bool? ?? false,
    ownerId: j['ownerId'] as String,
    ownerName: j['ownerName'] as String? ?? '',
    role: VaultRole.parse(j['role']),
    encryptedName: j['encryptedName'] as String,
    sealedKey: j['sealedKey'] as String,
    memberCount: (j['memberCount'] as num?)?.toInt() ?? 1,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'personal': personal,
    'ownerId': ownerId,
    'ownerName': ownerName,
    'role': role.name,
    'encryptedName': encryptedName,
    'sealedKey': sealedKey,
    'memberCount': memberCount,
  };
}

class EntryDto {
  const EntryDto({
    required this.id,
    required this.vaultId,
    required this.revision,
    required this.deleted,
    required this.data,
    this.updatedAt,
  });
  final String id;
  final String vaultId;
  final int revision;
  final bool deleted;

  /// Encrypted [OtpEntry] JSON; empty for deleted entries.
  final String data;
  final DateTime? updatedAt;

  factory EntryDto.fromJson(Map<String, Object?> j) => EntryDto(
    id: j['id'] as String,
    vaultId: j['vaultId'] as String,
    revision: (j['revision'] as num).toInt(),
    deleted: j['deleted'] as bool? ?? false,
    data: j['data'] as String? ?? '',
    updatedAt: _date(j['updatedAt']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'vaultId': vaultId,
    'revision': revision,
    'deleted': deleted,
    'data': data,
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };
}

class SyncResult {
  const SyncResult({
    required this.cursor,
    required this.vaults,
    required this.entries,
    required this.resetVaults,
  });
  final int cursor;

  /// All vaults the user currently belongs to.
  final List<VaultDto> vaults;

  /// Changed (or, for [resetVaults], all) entries since the given cursor.
  final List<EntryDto> entries;

  /// Vaults whose entries are sent in full, e.g. after being shared with
  /// the user; local copies of them are replaced.
  final Set<String> resetVaults;

  factory SyncResult.fromJson(Map<String, Object?> j) => SyncResult(
    cursor: (j['cursor'] as num).toInt(),
    vaults: [
      for (final v in j['vaults'] as List) VaultDto.fromJson((v as Map).cast()),
    ],
    entries: [
      for (final e in j['entries'] as List)
        EntryDto.fromJson((e as Map).cast()),
    ],
    resetVaults: {...(j['resetVaults'] as List? ?? const []).cast<String>()},
  );
}

class SessionDto {
  const SessionDto({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.createdAt,
    required this.lastSeenAt,
    required this.current,
  });
  final String id;
  final String deviceName;
  final String platform;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final bool current;

  factory SessionDto.fromJson(Map<String, Object?> j) => SessionDto(
    id: j['id'] as String,
    deviceName: j['deviceName'] as String? ?? '',
    platform: j['platform'] as String? ?? '',
    createdAt: _date(j['createdAt']),
    lastSeenAt: _date(j['lastSeenAt']),
    current: j['current'] as bool? ?? false,
  );
}

class MemberDto {
  const MemberDto({
    required this.userId,
    required this.username,
    required this.role,
    required this.publicKey,
  });
  final String userId;
  final String username;
  final VaultRole role;
  final String publicKey;

  factory MemberDto.fromJson(Map<String, Object?> j) => MemberDto(
    userId: j['userId'] as String,
    username: j['username'] as String,
    role: VaultRole.parse(j['role']),
    publicKey: j['publicKey'] as String,
  );
}

class UserDto {
  const UserDto({
    required this.id,
    required this.username,
    required this.publicKey,
    this.isAdmin = false,
    this.disabled = false,
    this.createdAt,
  });
  final String id;
  final String username;
  final String publicKey;
  final bool isAdmin;
  final bool disabled;
  final DateTime? createdAt;

  factory UserDto.fromJson(Map<String, Object?> j) => UserDto(
    id: j['id'] as String,
    username: j['username'] as String,
    publicKey: j['publicKey'] as String? ?? '',
    isAdmin: j['isAdmin'] as bool? ?? false,
    disabled: j['disabled'] as bool? ?? false,
    createdAt: _date(j['createdAt']),
  );
}

class InviteDto {
  const InviteDto({
    required this.id,
    required this.note,
    required this.createdAt,
    required this.expiresAt,
    this.code,
  });
  final String id;
  final String note;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  /// Only present right after creation.
  final String? code;

  factory InviteDto.fromJson(Map<String, Object?> j) => InviteDto(
    id: j['id'] as String,
    note: j['note'] as String? ?? '',
    createdAt: _date(j['createdAt']),
    expiresAt: _date(j['expiresAt']),
    code: j['code'] as String?,
  );
}

class AuditDto {
  const AuditDto({
    required this.at,
    required this.event,
    required this.detail,
    required this.username,
    required this.ip,
  });
  final DateTime? at;
  final String event;
  final String detail;
  final String username;
  final String ip;

  factory AuditDto.fromJson(Map<String, Object?> j) => AuditDto(
    at: _date(j['at']),
    event: j['event'] as String? ?? '',
    detail: j['detail'] as String? ?? '',
    username: j['username'] as String? ?? '',
    ip: j['ip'] as String? ?? '',
  );
}
