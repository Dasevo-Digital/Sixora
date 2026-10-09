import 'package:flutter/material.dart';

import '../platform/backup_folder.dart';
import '../widgets/common.dart';

/// Writes an encrypted backup into a folder of the user's choice, e.g.
/// iCloud Drive, Nextcloud or a USB stick – independent of the server.
class AutoBackupScreen extends StatelessWidget {
  const AutoBackupScreen({super.key});

  Future<void> _setUp(BuildContext context) async {
    final c = AppScope.read(context);
    final FolderRef? folder;
    try {
      folder = await BackupFolder.pick();
    } on Object catch (e) {
      if (context.mounted) showError(context, e);
      return;
    }
    if (folder == null || !context.mounted) return;
    final pw = await askNewBackupPassword(context);
    if (pw == null || !context.mounted) return;
    await runBusy(
      context,
      () => c.enableAutoBackup(folder!, pw),
      message: 'Erste Sicherung wird geschrieben …',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final s = c.settings;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Automatische Sicherung')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'Sixora schreibt nach Änderungen eine verschlüsselte Sicherung '
              'aller Konten in einen Ordner deiner Wahl, zum Beispiel in die '
              'iCloud, in Nextcloud oder auf einen USB-Stick. So bleibt eine '
              'Kopie, auch wenn Server oder Konto verloren gehen.\n\n'
              'Pro Tag entsteht eine Datei, die letzten 14 bleiben. Geschrieben '
              'wird nur, solange Sixora entsperrt ist. Öffnen lässt sich eine '
              'Sicherung mit ihrem Passwort über „Importieren“, auch in einem '
              'neuen Konto.',
            ),
          ),
          if (!c.autoBackup)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => _setUp(context),
                icon: const Icon(Icons.folder_open),
                label: const Text('Ordner wählen und einrichten'),
              ),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Ordner'),
              subtitle: Text(s.backupFolderLabel),
            ),
            ListTile(
              leading: Icon(
                s.backupError == null
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: s.backupError == null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              title: Text(
                s.backupError == null
                    ? 'Letzte Sicherung'
                    : 'Letzte Sicherung fehlgeschlagen',
              ),
              subtitle: Text(
                s.backupError == null
                    ? formatDate(s.lastBackup)
                    : '${s.backupError}\nZuletzt erfolgreich: ${formatDate(s.lastBackup)}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Jetzt sichern'),
              onTap: () async {
                final ok = await runBusy(context, () async {
                  await c.backupNow();
                  return true;
                });
                if (ok == true && context.mounted) {
                  showMessage(context, 'Sicherung geschrieben');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('Anderen Ordner oder neues Passwort'),
              onTap: () => _setUp(context),
            ),
            ListTile(
              leading: Icon(Icons.block, color: theme.colorScheme.error),
              title: Text(
                'Ausschalten',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Text('Vorhandene Dateien bleiben im Ordner'),
              onTap: c.disableAutoBackup,
            ),
          ],
        ],
      ),
    );
  }
}
