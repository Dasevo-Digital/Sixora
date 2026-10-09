import 'dart:io';

import 'package:sixora_server/sixora_server.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Daily copies, checks and schema migrations.
void main() {
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.start();
  });
  tearDown(() => h.stop());

  test('one copy per day, the newest backupDays are kept', () async {
    final dir = await Directory.systemTemp.createTemp('sixora-backup');
    addTearDown(() => dir.delete(recursive: true));
    var now = DateTime.utc(2026, 3, 1, 2);
    final app = SixoraServerApp(
      db: openSixoraDatabase('${dir.path}/sixora.db'),
      registration: Registration.open,
      dataDir: dir.path,
      backupDays: 3,
      clock: () => now,
    );
    for (var day = 0; day < 6; day++) {
      app.maintain();
      app.maintain(); // twice a day: still one file
      now = now.add(const Duration(days: 1));
    }
    final files = Directory(
      '${dir.path}/backups',
    ).listSync().map((f) => f.uri.pathSegments.last).toList()..sort();
    // backupDays: 3 → the three newest daily copies.
    expect(files, [
      'sixora-2026-03-04.db',
      'sixora-2026-03-05.db',
      'sixora-2026-03-06.db',
    ]);
    // A real, openable database.
    final copy = openSixoraDatabase('${dir.path}/backups/${files.last}');
    expect(copy.select('SELECT COUNT(*) AS n FROM users').first['n'], 0);
    copy.close();
    app.db.close();
  });

  test('a backup is read back; broken copies are reported', () async {
    final dir = await Directory.systemTemp.createTemp('sixora-verify');
    addTearDown(() => dir.delete(recursive: true));
    final app = SixoraServerApp(
      db: openSixoraDatabase('${dir.path}/sixora.db'),
      registration: Registration.open,
      dataDir: dir.path,
    );
    app.db.execute(
      "INSERT INTO users (id, username, kdf, salt, auth_hash, wrapped_user_key, "
      "public_key, encrypted_private_key, recovery_wrapped_user_key, "
      "recovery_auth_hash, created_at, updated_at) VALUES "
      "('u1', 'alice', '{}', 's', 'a', 'w', 'p', 'e', 'r', 'h', 'now', 'now')",
    );
    final path = app.backup()!;
    final check = BackupCheck.inspect(path);
    expect(check.ok, isTrue, reason: check.problem);
    expect(check.schema, 4);
    expect(check.counts['users'], 1);
    expect(BackupCheck.newest('${dir.path}/backups'), path);

    // A damaged copy is not "in Ordnung".
    final broken = File('${dir.path}/backups/sixora-2000-01-01.db')
      ..writeAsBytesSync(List.filled(4096, 7));
    final bad = BackupCheck.inspect(broken.path);
    expect(bad.ok, isFalse);
    expect(bad.problem, isNotEmpty);
    expect(BackupCheck.inspect('${dir.path}/fehlt.db').ok, isFalse);
    app.db.close();
  });

  test('an old database gets the recycle bin columns', () {
    final db = openSixoraDatabase(':memory:');
    final columns = db
        .select('PRAGMA table_info(entries)')
        .map((r) => r['name'])
        .toList();
    expect(columns, containsAll(['deleted_at', 'trash_data']));
    expect(
      db.select('PRAGMA table_info(vaults)').map((r) => r['name']),
      containsAll(['key_version', 'rotate_pending']),
    );
    expect(
      db.select('PRAGMA table_info(users)').map((r) => r['name']),
      containsAll(['contacts', 'contacts_revision']),
    );
    expect(db.select('PRAGMA user_version').first.columnAt(0), 4);
    db.close();
  });
}
