import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sixora_core/sixora_core.dart';

import '../data/biometric_vault.dart';
import '../data/local_store.dart';
import '../widgets/common.dart';
import '../platform/desktop_shell.dart';
import '../platform/link_inbox.dart';
import 'account_screens.dart';
import 'account_check_screen.dart';
import 'admin_screen.dart';
import 'auto_backup_screen.dart';
import 'entry_qr_screen.dart';
import 'import_screen.dart';
import 'recovery_key_screen.dart';
import 'trash_screen.dart';
import 'vaults_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final s = c.settings;
    final account = c.account!;
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            children: [
              ListTile(
                leading: CircleAvatar(
                  child: Text(account.username.characters.first.toUpperCase()),
                ),
                title: Text(account.username),
                subtitle: Text(
                  '${c.cached!.serverName} · ${c.cached!.server.host}'
                  '${account.isAdmin ? ' · Administrator' : ''}\n'
                  'Zuletzt synchronisiert: ${formatDate(c.cached!.lastSync)}',
                ),
                isThreeLine: true,
              ),
              const SectionTitle('Sicherheit'),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Automatisch sperren'),
                subtitle: Text(s.autoLock.label),
                onTap: () async {
                  final value = await showDialog<AutoLock>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: const Text('Automatisch sperren'),
                      children: [
                        RadioGroup<AutoLock>(
                          groupValue: s.autoLock,
                          onChanged: (v) => Navigator.pop(context, v),
                          child: Column(
                            children: [
                              for (final a in AutoLock.values)
                                RadioListTile<AutoLock>(
                                  value: a,
                                  title: Text(a.label),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                  if (value != null) {
                    s.autoLock = value;
                    await c.saveSettings();
                  }
                },
              ),
              if (c.biometricsAvailable)
                SwitchListTile(
                  secondary: Icon(biometricIcon(c.biometricLabel)),
                  title: Text('Mit ${c.biometricLabel} entsperren'),
                  subtitle: Text(
                    BiometricVault.hardwareBound
                        ? 'Statt des Master-Passworts. Der Schlüssel ist an die '
                              'Biometrie dieses Geräts gebunden; wird ein neuer Finger '
                              'oder ein neues Gesicht registriert, braucht es wieder das '
                              'Passwort.'
                        : 'Statt des Master-Passworts. Der Schlüssel liegt dafür im '
                              'Schlüsselbund dieses Geräts.',
                  ),
                  value: c.quickUnlockReady,
                  onChanged: (v) async {
                    try {
                      await c.setQuickUnlock(v);
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                ),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off_outlined),
                title: const Text('Codes verbergen'),
                subtitle: const Text('Erst nach Antippen anzeigen'),
                value: s.hideCodes,
                onChanged: (v) {
                  s.hideCodes = v;
                  c.saveSettings();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.content_paste_off),
                title: const Text('Zwischenablage leeren'),
                subtitle: const Text(
                  'Kopierte Codes nach 30 Sekunden entfernen',
                ),
                value: s.clearClipboard,
                onChanged: (v) {
                  s.clearClipboard = v;
                  c.saveSettings();
                },
              ),
              if (Theme.of(context).platform == TargetPlatform.android)
                SwitchListTile(
                  secondary: const Icon(Icons.screenshot_outlined),
                  title: const Text('Bildschirmfotos erlauben'),
                  subtitle: const Text(
                    'Sonst sind Screenshots und Bildschirmaufnahmen gesperrt',
                  ),
                  value: s.allowScreenshots,
                  onChanged: (v) {
                    s.allowScreenshots = v;
                    c.saveSettings();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.password),
                title: const Text('Master-Passwort ändern'),
                onTap: () => _changePassword(context),
              ),
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: const Text('Neuer Wiederherstellungsschlüssel'),
                subtitle: const Text('Der bisherige wird ungültig'),
                onTap: () => _renewRecovery(context),
              ),
              ListTile(
                leading: const Icon(Icons.devices_outlined),
                title: const Text('Angemeldete Geräte'),
                onTap: () => _open(context, const SessionsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Papierkorb'),
                subtitle: const Text('Gelöschte Konten der letzten 30 Tage'),
                onTap: () => _open(context, const TrashScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Aktivitäten'),
                subtitle: const Text('Anmeldungen und Änderungen am Konto'),
                onTap: () => _open(context, const AuditScreen()),
              ),
              if (DesktopShell.supported) ...[
                const SectionTitle('Schreibtisch'),
                SwitchListTile(
                  secondary: const Icon(Icons.menu_open),
                  title: Text(
                    Theme.of(context).platform == TargetPlatform.macOS
                        ? 'In der Menüleiste weiterlaufen'
                        : 'Im Infobereich weiterlaufen',
                  ),
                  subtitle: const Text(
                    'Beim Schließen des Fensters bleibt Sixora erreichbar. '
                    'Über das Symbol lassen sich die Codes der Favoriten '
                    'kopieren oder alle Konten durchsuchen.',
                  ),
                  value: s.keepInTray,
                  onChanged: (v) async {
                    s.keepInTray = v;
                    await c.saveSettings();
                    await DesktopShell.instance?.applySettings();
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.keyboard_command_key),
                  title: Text('Tastenkürzel ${DesktopShell.shortcutLabel}'),
                  subtitle: const Text(
                    'Holt Sixora von überall nach vorn, mit dem Cursor in der Suche.',
                  ),
                  value: s.globalHotkey,
                  onChanged: (v) async {
                    s.globalHotkey = v;
                    await c.saveSettings();
                    await DesktopShell.instance?.applySettings();
                  },
                ),
                const _LinkHandlerTile(),
              ],
              const SectionTitle('Anzeige'),
              SwitchListTile(
                secondary: const Icon(Icons.update),
                title: const Text('Nächsten Code anzeigen'),
                subtitle: const Text('In den letzten 5 Sekunden eines Codes'),
                value: s.showNextCode,
                onChanged: (v) {
                  s.showNextCode = v;
                  c.saveSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Erscheinungsbild'),
                trailing: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'system', label: Text('System')),
                    ButtonSegment(value: 'light', label: Text('Hell')),
                    ButtonSegment(value: 'dark', label: Text('Dunkel')),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) {
                    s.themeMode = v.first;
                    c.saveSettings();
                  },
                ),
              ),
              const SectionTitle('Tresore und Daten'),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Tresore und Teilen'),
                subtitle: Text(
                  '${c.vaults.length} ${c.vaults.length == 1 ? 'Tresor' : 'Tresore'}',
                ),
                onTap: () => _open(context, const VaultsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Importieren'),
                onTap: () => _open(context, const ImportScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('Exportieren'),
                subtitle: const Text(
                  'Verschlüsselte Sicherung, Textdatei oder QR-Codes',
                ),
                onTap: () => _export(context),
              ),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Automatische Sicherung'),
                subtitle: Text(
                  !c.autoBackup
                      ? 'Aus'
                      : s.backupError != null
                      ? 'Fehler: ${s.backupError}'
                      : '${s.backupFolderLabel} · zuletzt ${formatDate(s.lastBackup)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _open(context, const AutoBackupScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: const Text('Kontenprüfung'),
                subtitle: const Text(
                  'Doppelte Konten, schwache Schlüssel, fehlende Logos',
                ),
                onTap: () => _open(context, const AccountCheckScreen()),
              ),
              if (account.isAdmin) ...[
                const SectionTitle('Server'),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Verwaltung'),
                  subtitle: const Text('Benutzer, Einladungen, Protokoll'),
                  onTap: () => _open(context, const AdminScreen()),
                ),
              ],
              const SectionTitle('Konto'),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Abmelden'),
                subtitle: const Text(
                  'Entfernt die lokale Kopie von diesem Gerät',
                ),
                onTap: () async {
                  final ok = await confirm(
                    context,
                    title: 'Abmelden?',
                    message:
                        'Deine Codes bleiben auf dem Server. Zum erneuten Anmelden '
                        'brauchst du Benutzername und Master-Passwort.',
                    action: 'Abmelden',
                  );
                  if (ok) await c.logout();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Konto löschen',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _deleteAccount(context),
              ),
              const SectionTitle('Über'),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) => ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Sixora'),
                  subtitle: Text(
                    'Version ${snap.data?.version ?? '…'}\n'
                    'Codes werden auf deinen Geräten berechnet. Der Server '
                    'speichert nur verschlüsselte Daten.',
                  ),
                  isThreeLine: true,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Sixora',
                    applicationVersion: snap.data?.version,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final c = AppScope.read(context);
    final current = TextEditingController();
    final next = TextEditingController();
    final repeat = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Master-Passwort ändern'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PasswordField(
                controller: current,
                label: 'Aktuelles Passwort',
                autofocus: true,
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: next,
                label: 'Neues Passwort',
                autofillHints: const [AutofillHints.newPassword],
                helper:
                    'Mindestens 10 Zeichen. Andere Geräte werden abgemeldet.',
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: repeat,
                label: 'Neues Passwort wiederholen',
                autofillHints: const [AutofillHints.newPassword],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ändern'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (next.text.length < 10) {
      showMessage(context, 'Das neue Passwort braucht mindestens 10 Zeichen');
      return;
    }
    if (next.text != repeat.text) {
      showMessage(context, 'Die neuen Passwörter stimmen nicht überein');
      return;
    }
    final done = await runBusy(context, () async {
      await c.changePassword(current.text, next.text);
      return true;
    }, message: 'Passwort wird geändert …');
    if (done == true && context.mounted) {
      showMessage(
        context,
        'Master-Passwort geändert. Andere Geräte müssen sich neu anmelden.',
      );
    }
  }

  Future<void> _renewRecovery(BuildContext context) async {
    final c = AppScope.read(context);
    final password = await askText(
      context,
      title: 'Neuer Wiederherstellungsschlüssel',
      message:
          'Zur Bestätigung das Master-Passwort eingeben. Der bisherige Schlüssel wird ungültig.',
      label: 'Master-Passwort',
      password: true,
      action: 'Erzeugen',
    );
    if (password == null || !context.mounted) return;
    final key = await runBusy(context, () => c.renewRecoveryKey(password));
    if (key != null && context.mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => RecoveryKeyScreen(
            recoveryKey: key,
            username: c.account!.username,
            renewed: true,
          ),
        ),
      );
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final c = AppScope.read(context);
    final ok = await confirm(
      context,
      title: 'Konto endgültig löschen?',
      message:
          'Alle deine Codes und die Tresore, die dir gehören – auch geteilte –, '
          'werden auf dem Server gelöscht. Das lässt sich nicht rückgängig machen. '
          'Deaktiviere vorher die Zwei-Faktor-Anmeldung bei den Diensten oder '
          'exportiere deine Konten.',
      action: 'Weiter',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final password = await askText(
      context,
      title: 'Master-Passwort bestätigen',
      label: 'Master-Passwort',
      password: true,
      action: 'Konto löschen',
    );
    if (password == null || !context.mounted) return;
    await runBusy(context, () => c.deleteAccount(password));
  }

  Future<void> _export(BuildContext context) async {
    final c = AppScope.read(context);
    final entries = [for (final i in c.items) i.entry];
    if (entries.isEmpty) {
      showMessage(context, 'Keine Konten zum Exportieren');
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Verschlüsselte Sicherung'),
              subtitle: const Text(
                'Mit eigenem Passwort, lässt sich in Sixora importieren',
              ),
              onTap: () => Navigator.pop(context, 'backup'),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: const Text('QR-Codes für Google Authenticator'),
              subtitle: const Text('Zum Übertragen in eine andere App'),
              onTap: () => Navigator.pop(context, 'qr'),
            ),
            ListTile(
              leading: Icon(
                Icons.warning_amber,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Unverschlüsselte Textdatei'),
              subtitle: const Text(
                'otpauth-Links, für andere Apps – nur mit Vorsicht',
              ),
              onTap: () => Navigator.pop(context, 'plain'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    switch (choice) {
      case 'backup':
        final pw = await askNewBackupPassword(context);
        if (pw == null || !context.mounted) return;
        final text = await runBusy(
          context,
          () => SixoraBackup.encrypt(entries, pw),
          message: 'Sicherung wird verschlüsselt …',
        );
        if (text == null || !context.mounted) return;
        await _save(
          context,
          'Sixora-Sicherung-$stamp.json',
          text,
          'application/json',
        );
      case 'qr':
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => EntryQrScreen(entries: entries)),
        );
      case 'plain':
        final ok = await confirm(
          context,
          title: 'Unverschlüsselt exportieren?',
          message:
              'Die Datei enthält alle geheimen Schlüssel im Klartext. Wer sie '
              'liest, kann deine Codes erzeugen. Nach dem Import sofort löschen.',
          action: 'Exportieren',
          destructive: true,
        );
        if (!ok || !context.mounted) return;
        await _save(
          context,
          'Sixora-Export-$stamp.txt',
          SixoraBackup.plainUris(entries),
          'text/plain',
        );
    }
  }

  Future<void> _save(
    BuildContext context,
    String name,
    String text,
    String mime,
  ) async {
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Speichern unter',
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(text)),
        mimeType: mime,
      );
      if (uri != null && context.mounted) showMessage(context, 'Gespeichert');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

/// macOS: offers to open otpauth:// links with Sixora, as long as another
/// app (usually Apple's Passwords) gets them.
class _LinkHandlerTile extends StatefulWidget {
  const _LinkHandlerTile();

  @override
  State<_LinkHandlerTile> createState() => _LinkHandlerTileState();
}

class _LinkHandlerTileState extends State<_LinkHandlerTile> {
  ({bool isDefault, String app})? _state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await LinkInbox.handler();
    if (mounted) setState(() => _state = state);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.link),
      title: const Text('otpauth-Links mit Sixora öffnen'),
      subtitle: Text(
        state.isDefault
            ? 'Links zum Einrichten von Konten öffnen Sixora.'
            : 'Zurzeit öffnet sie ${state.app.isEmpty ? 'eine andere App' : '„${state.app}“'}.',
      ),
      trailing: state.isDefault
          ? Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            )
          : FilledButton.tonal(
              onPressed: () async {
                try {
                  await LinkInbox.makeDefault();
                } on Object catch (e) {
                  if (context.mounted) {
                    showMessage(
                      context,
                      'Nicht geändert: ${e is PlatformException ? e.message : e}',
                    );
                  }
                }
                await _load();
              },
              child: const Text('Sixora verwenden'),
            ),
    );
  }
}
