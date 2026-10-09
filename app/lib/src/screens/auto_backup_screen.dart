import 'package:flutter/material.dart';

import '../l10n.dart';
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
      message: t.writingFirstBackup,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final s = c.settings;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.autoBackup)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(t.autoBackupExplanation),
          ),
          if (!c.autoBackup)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => _setUp(context),
                icon: const Icon(Icons.folder_open),
                label: Text(t.chooseFolderAndSetUp),
              ),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(t.folder),
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
                s.backupError == null ? t.lastBackup : t.lastBackupFailed,
              ),
              subtitle: Text(
                s.backupError == null
                    ? formatDate(s.lastBackup)
                    : t.backupErrorDetail(
                        s.backupError!,
                        formatDate(s.lastBackup),
                      ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: Text(t.backUpNow),
              onTap: () async {
                final ok = await runBusy(context, () async {
                  await c.backupNow();
                  return true;
                });
                if (ok == true && context.mounted) {
                  showMessage(context, t.backupWritten);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(t.verifyBackup),
              subtitle: Text(t.verifyBackupHint),
              onTap: () async {
                final r = await runBusy(context, c.verifyBackup);
                if (r == null || !context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    icon: Icon(
                      r.missing.isEmpty
                          ? Icons.verified_outlined
                          : Icons.info_outline,
                    ),
                    title: Text(
                      r.missing.isEmpty ? t.backupOk : t.backupNotCurrent,
                    ),
                    content: Text(
                      '${t.backupVerified(r.file, r.accounts, r.files)}'
                      '${r.missing.isEmpty ? '' : '\n\n${t.backupMissing(r.missing.join(', '))}'}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: Text(t.otherFolderOrPassword),
              onTap: () => _setUp(context),
            ),
            ListTile(
              leading: Icon(Icons.block, color: theme.colorScheme.error),
              title: Text(
                t.turnOff,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: Text(t.turnOffHint),
              onTap: c.disableAutoBackup,
            ),
          ],
        ],
      ),
    );
  }
}
