import 'dart:typed_data';

import 'package:sixora_core/sixora_core.dart';

/// What the extension keeps between two popups (`storage.local`): the
/// account as the server sent it, the session token and the encrypted copy
/// of the vaults. Nothing in here can be read without the master password,
/// just like on the server; even the token is encrypted with the user key,
/// so the browser profile alone cannot change anything on the server.
class StoredAccount {
  StoredAccount({
    required this.server,
    required this.serverName,
    required this.account,
    required this.encryptedToken,
    this.cursor = 0,
    this.lastSync,
    Map<String, VaultDto>? vaults,
    Map<String, EntryDto>? entries,
  }) : vaults = vaults ?? {},
       entries = entries ?? {};

  final Uri server;
  final String serverName;
  AccountBundle account;
  final String encryptedToken;
  int cursor;
  DateTime? lastSync;
  final Map<String, VaultDto> vaults;
  final Map<String, EntryDto> entries;

  static String _tokenAad(String accountId) => 'sixora-ext-token|$accountId';

  static Future<String> encryptToken(
    Uint8List userKey,
    String accountId,
    String token,
  ) => VaultCrypto.encryptString(userKey, token, aad: _tokenAad(accountId));

  Future<String> token(Uint8List userKey) => VaultCrypto.decryptString(
    userKey,
    encryptedToken,
    aad: _tokenAad(account.id),
  );

  Map<String, Object?> toJson() => {
    'server': server.toString(),
    'serverName': serverName,
    'account': account.toJson(),
    'token': encryptedToken,
    'cursor': cursor,
    'lastSync': lastSync?.toIso8601String(),
    'vaults': [for (final v in vaults.values) v.toJson()],
    'entries': [for (final e in entries.values) e.toJson()],
  };

  factory StoredAccount.fromJson(Map<String, Object?> j) => StoredAccount(
    server: Uri.parse(j['server']! as String),
    serverName: j['serverName'] as String? ?? '',
    account: AccountBundle.fromJson((j['account']! as Map).cast()),
    encryptedToken: j['token']! as String,
    cursor: j['cursor'] as int? ?? 0,
    lastSync: DateTime.tryParse(j['lastSync'] as String? ?? ''),
    vaults: {
      for (final v in j['vaults'] as List? ?? const [])
        if (VaultDto.fromJson((v as Map).cast()) case final dto) dto.id: dto,
    },
    entries: {
      for (final e in j['entries'] as List? ?? const [])
        if (EntryDto.fromJson((e as Map).cast()) case final dto) dto.id: dto,
    },
  );

  /// Takes over a sync answer, like the apps do.
  void apply(SyncResult r) {
    // An answer older than what is stored would bring back old entries.
    if (r.cursor < cursor) return;
    final ids = {for (final v in r.vaults) v.id};
    vaults
      ..clear()
      ..addAll({for (final v in r.vaults) v.id: v});
    entries.removeWhere(
      (_, e) => !ids.contains(e.vaultId) || r.resetVaults.contains(e.vaultId),
    );
    for (final e in r.entries) {
      if (e.deleted) {
        entries.remove(e.id);
      } else {
        entries[e.id] = e;
      }
    }
    cursor = r.cursor;
    lastSync = DateTime.now();
  }
}

/// A decrypted account in the list.
class Code {
  Code(this.id, this.vault, this.entry);
  final String id;

  /// Name of the vault it is in.
  final String vault;
  final OtpEntry entry;
}

/// Opens the vault keys and decrypts every entry. HOTP is left out: using
/// its code moves the counter, which the extension does not write. Returns
/// the accounts (favourites first, then by name) and how many could not be
/// read.
Future<({List<Code> codes, int unreadable})> decryptCodes(
  StoredAccount stored,
  UnlockedKeys keys,
) async {
  final vaultKeys = <String, Uint8List>{};
  final names = <String, String>{};
  for (final v in stored.vaults.values) {
    try {
      final key = await keys.openVaultKey(v);
      vaultKeys[v.id] = key;
      names[v.id] = await UnlockedKeys.decryptVaultName(
        key,
        v.id,
        v.encryptedName,
      );
    } on CryptoException {
      // Counted below with its entries.
    }
  }
  final codes = <Code>[];
  var unreadable = 0;
  for (final e in stored.entries.values) {
    final key = vaultKeys[e.vaultId];
    if (key == null) {
      unreadable++;
      continue;
    }
    try {
      final entry = await UnlockedKeys.decryptEntry(
        key,
        e.vaultId,
        e.id,
        e.data,
      );
      if (entry.type != OtpType.hotp) {
        codes.add(Code(e.id, names[e.vaultId]!, entry));
      }
    } on Object {
      unreadable++;
    }
  }
  codes.sort((a, b) {
    if (a.entry.favorite != b.entry.favorite) return a.entry.favorite ? -1 : 1;
    final byName = a.entry.displayName.toLowerCase().compareTo(
      b.entry.displayName.toLowerCase(),
    );
    return byName != 0 ? byName : a.entry.account.compareTo(b.entry.account);
  });
  return (codes: codes, unreadable: unreadable);
}
