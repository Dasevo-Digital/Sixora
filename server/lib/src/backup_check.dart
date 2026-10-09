import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// What a database copy contains, read without changing it.
class BackupCheck {
  const BackupCheck({
    required this.path,
    required this.ok,
    required this.problem,
    required this.schema,
    required this.counts,
  });

  final String path;
  final bool ok;

  /// Why the copy is unusable; empty when [ok].
  final String problem;
  final int schema;

  /// users, vaults, entries (not deleted), members.
  final Map<String, int> counts;

  static const tables = {
    'users': 'SELECT COUNT(*) FROM users',
    'vaults': 'SELECT COUNT(*) FROM vaults',
    'entries': 'SELECT COUNT(*) FROM entries WHERE deleted = 0',
    'members': 'SELECT COUNT(*) FROM vault_members',
  };

  /// Opens [path] read-only: integrity check, schema version and counts.
  static BackupCheck inspect(String path) {
    if (!File(path).existsSync()) {
      return BackupCheck(
        path: path,
        ok: false,
        problem: 'Datei fehlt',
        schema: 0,
        counts: const {},
      );
    }
    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
      final integrity = db.select('PRAGMA integrity_check').first.columnAt(0);
      final schema = db.select('PRAGMA user_version').first.columnAt(0) as int;
      return BackupCheck(
        path: path,
        ok: integrity == 'ok',
        problem: integrity == 'ok' ? '' : 'Integritätsprüfung: $integrity',
        schema: schema,
        counts: countsOf(db),
      );
    } on SqliteException catch (e) {
      return BackupCheck(
        path: path,
        ok: false,
        problem: e.message,
        schema: 0,
        counts: const {},
      );
    } finally {
      db?.close();
    }
  }

  static Map<String, int> countsOf(Database db) => {
    for (final t in tables.entries)
      t.key: db.select(t.value).first.columnAt(0) as int,
  };

  /// The newest `sixora-YYYY-MM-DD.db` in [folder], if any.
  static String? newest(String folder) {
    final dir = Directory(folder);
    if (!dir.existsSync()) return null;
    final files = [
      for (final f in dir.listSync().whereType<File>())
        if (RegExp(r'sixora-\d{4}-\d{2}-\d{2}\.db$').hasMatch(f.path)) f.path,
    ]..sort((a, b) => p.basename(a).compareTo(p.basename(b)));
    return files.isEmpty ? null : files.last;
  }

  String describe() => ok
      ? 'Schema $schema, ${describeCounts(counts)}'
      : 'unbrauchbar: $problem';

  static String describeCounts(Map<String, int> counts) =>
      '${counts['users']} Benutzer, ${counts['vaults']} Tresore, '
      '${counts['entries']} Einträge';
}
