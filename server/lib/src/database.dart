import 'package:sqlite3/sqlite3.dart';

const _schemaVersion = 4;

/// Opens (and migrates) the server database.
///
/// The database never contains an OTP secret or a key in plaintext: entries,
/// vault names and all key material are encrypted on the clients.
Database openSixoraDatabase(String path) {
  final db = path == ':memory:' ? sqlite3.openInMemory() : sqlite3.open(path);
  db.execute('PRAGMA journal_mode = WAL');
  db.execute('PRAGMA foreign_keys = ON');
  db.execute('PRAGMA busy_timeout = 5000');
  db.execute('PRAGMA secure_delete = ON');
  _migrate(db);
  return db;
}

void _migrate(Database db) {
  final version = db.select('PRAGMA user_version').first.columnAt(0) as int;
  if (version > _schemaVersion) {
    throw StateError(
      'Datenbank stammt von einer neueren Server-Version ($version)',
    );
  }
  if (version < 1) {
    db.execute('''
      CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
      INSERT INTO meta (key, value) VALUES ('seq', '0');

      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE COLLATE NOCASE,
        is_admin INTEGER NOT NULL DEFAULT 0,
        disabled INTEGER NOT NULL DEFAULT 0,
        kdf TEXT NOT NULL,
        salt TEXT NOT NULL,
        auth_hash TEXT NOT NULL,
        wrapped_user_key TEXT NOT NULL,
        public_key TEXT NOT NULL,
        encrypted_private_key TEXT NOT NULL,
        recovery_wrapped_user_key TEXT NOT NULL,
        recovery_auth_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token_hash TEXT NOT NULL UNIQUE,
        device_name TEXT NOT NULL,
        platform TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_seen_at TEXT NOT NULL,
        ip TEXT NOT NULL DEFAULT ''
      );
      CREATE INDEX sessions_user ON sessions(user_id);

      CREATE TABLE vaults (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        personal INTEGER NOT NULL DEFAULT 0,
        encrypted_name TEXT NOT NULL,
        created_at TEXT NOT NULL
      );

      CREATE TABLE vault_members (
        vault_id TEXT NOT NULL REFERENCES vaults(id) ON DELETE CASCADE,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        role TEXT NOT NULL,
        sealed_key TEXT NOT NULL,
        seq INTEGER NOT NULL,
        added_at TEXT NOT NULL,
        PRIMARY KEY (vault_id, user_id)
      );
      CREATE INDEX vault_members_user ON vault_members(user_id);

      CREATE TABLE entries (
        id TEXT PRIMARY KEY,
        vault_id TEXT NOT NULL REFERENCES vaults(id) ON DELETE CASCADE,
        data TEXT NOT NULL,
        revision INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        seq INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        updated_by TEXT NOT NULL DEFAULT ''
      );
      CREATE INDEX entries_vault_seq ON entries(vault_id, seq);

      CREATE TABLE invites (
        id TEXT PRIMARY KEY,
        code_hash TEXT NOT NULL UNIQUE,
        note TEXT NOT NULL DEFAULT '',
        created_by TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        expires_at TEXT NOT NULL
      );

      CREATE TABLE audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        at TEXT NOT NULL,
        user_id TEXT NOT NULL DEFAULT '',
        username TEXT NOT NULL DEFAULT '',
        event TEXT NOT NULL,
        detail TEXT NOT NULL DEFAULT '',
        ip TEXT NOT NULL DEFAULT ''
      );
      CREATE INDEX audit_user ON audit(user_id, id);
    ''');
  }
  if (version < 2) {
    // Recycle bin: a deleted entry keeps its ciphertext here for 30 days.
    // `data` stays empty, so the normal sync never hands it out again.
    db.execute('''
      ALTER TABLE entries ADD COLUMN deleted_at TEXT;
      ALTER TABLE entries ADD COLUMN trash_data TEXT NOT NULL DEFAULT '';
      CREATE INDEX entries_trash ON entries(vault_id, deleted, deleted_at);
    ''');
  }
  if (version < 3) {
    // Key rotation: a vault whose member left needs a new key, made by the
    // owner's next device online. Writes name the key version they used.
    db.execute('''
      ALTER TABLE vaults ADD COLUMN key_version INTEGER NOT NULL DEFAULT 1;
      ALTER TABLE vaults ADD COLUMN rotate_pending INTEGER NOT NULL DEFAULT 0;
    ''');
  }
  if (version < 4) {
    // Public keys of other users this account trusts (encrypted by the
    // client): a server cannot slip a key of its own in when vaults are
    // shared or get a new key.
    db.execute('''
      ALTER TABLE users ADD COLUMN contacts TEXT NOT NULL DEFAULT '';
      ALTER TABLE users ADD COLUMN contacts_revision INTEGER NOT NULL DEFAULT 0;
    ''');
  }
  db.execute('PRAGMA user_version = $_schemaVersion');
}
