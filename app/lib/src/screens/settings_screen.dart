import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sixora_core/sixora_core.dart';

import '../data/biometric_vault.dart';
import '../data/local_store.dart';
import '../l10n.dart';
import '../platform/desktop_shell.dart';
import '../platform/link_inbox.dart';
import '../widgets/common.dart';
import 'account_check_screen.dart';
import 'account_screens.dart';
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
      appBar: AppBar(title: Text(t.settings)),
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
                  '${account.isAdmin ? ' · ${t.administrator}' : ''}\n'
                  '${t.lastSynced(formatDate(c.cached!.lastSync))}',
                ),
                isThreeLine: true,
              ),
              SectionTitle(t.sectionSecurity),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(t.autoLock),
                subtitle: Text(s.autoLock.label),
                onTap: () async {
                  final value = await showDialog<AutoLock>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text(t.autoLock),
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
                  title: Text(t.unlockWith(c.biometricLabel)),
                  subtitle: Text(
                    BiometricVault.hardwareBound
                        ? t.quickUnlockHardwareHint
                        : t.quickUnlockKeychainHint,
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
                title: Text(t.hideCodes),
                subtitle: Text(t.hideCodesHint),
                value: s.hideCodes,
                onChanged: (v) {
                  s.hideCodes = v;
                  c.saveSettings();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.content_paste_off),
                title: Text(t.clearClipboard),
                subtitle: Text(t.clearClipboardHint),
                value: s.clearClipboard,
                onChanged: (v) {
                  s.clearClipboard = v;
                  c.saveSettings();
                },
              ),
              if (Theme.of(context).platform == TargetPlatform.android)
                SwitchListTile(
                  secondary: const Icon(Icons.screenshot_outlined),
                  title: Text(t.allowScreenshots),
                  subtitle: Text(t.allowScreenshotsHint),
                  value: s.allowScreenshots,
                  onChanged: (v) {
                    s.allowScreenshots = v;
                    c.saveSettings();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.password),
                title: Text(t.changeMasterPassword),
                onTap: () => _changePassword(context),
              ),
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: Text(t.newRecoveryKey),
                subtitle: Text(t.newRecoveryKeyHint),
                onTap: () => _renewRecovery(context),
              ),
              ListTile(
                leading: const Icon(Icons.devices_outlined),
                title: Text(t.signedInDevices),
                onTap: () => _open(context, const SessionsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(t.trash),
                subtitle: Text(t.trashHint),
                onTap: () => _open(context, const TrashScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(t.activity),
                subtitle: Text(t.activityHint),
                onTap: () => _open(context, const AuditScreen()),
              ),
              if (DesktopShell.supported) ...[
                SectionTitle(t.sectionDesktop),
                SwitchListTile(
                  secondary: const Icon(Icons.menu_open),
                  title: Text(
                    Theme.of(context).platform == TargetPlatform.macOS
                        ? t.keepInMenuBar
                        : t.keepInTray,
                  ),
                  subtitle: Text(t.keepInTrayHint),
                  value: s.keepInTray,
                  onChanged: (v) async {
                    s.keepInTray = v;
                    await c.saveSettings();
                    await DesktopShell.instance?.applySettings();
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.keyboard_command_key),
                  title: Text(t.shortcutTitle(DesktopShell.shortcutLabel)),
                  subtitle: Text(t.shortcutHint),
                  value: s.globalHotkey,
                  onChanged: (v) async {
                    s.globalHotkey = v;
                    await c.saveSettings();
                    await DesktopShell.instance?.applySettings();
                  },
                ),
                const _LinkHandlerTile(),
              ],
              SectionTitle(t.sectionDisplay),
              SwitchListTile(
                secondary: const Icon(Icons.update),
                title: Text(t.showNextCode),
                subtitle: Text(t.showNextCodeHint),
                value: s.showNextCode,
                onChanged: (v) {
                  s.showNextCode = v;
                  c.saveSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: Text(t.appearance),
                trailing: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'system', label: Text(t.themeSystem)),
                    ButtonSegment(value: 'light', label: Text(t.themeLight)),
                    ButtonSegment(value: 'dark', label: Text(t.themeDark)),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) {
                    s.themeMode = v.first;
                    c.saveSettings();
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(t.language),
                trailing: DropdownButton<String>(
                  value: s.language,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: 'system',
                      child: Text(t.languageSystem),
                    ),
                    // Each language under its own name.
                    for (final (code, name) in const [
                      ('de', 'Deutsch'),
                      ('en', 'English'),
                      ('es', 'Español'),
                    ])
                      DropdownMenuItem(value: code, child: Text(name)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    s.language = v;
                    c.saveSettings();
                  },
                ),
              ),
              SectionTitle(t.sectionVaultsData),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: Text(t.vaultsAndSharing),
                subtitle: Text(t.vaultCount(c.vaults.length)),
                onTap: () => _open(context, const VaultsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: Text(t.importAction),
                onTap: () => _open(context, const ImportScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: Text(t.exportAction),
                subtitle: Text(t.exportHint),
                onTap: () => _export(context),
              ),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: Text(t.autoBackup),
                subtitle: Text(
                  !c.autoBackup
                      ? t.off
                      : s.backupError != null
                      ? t.errorWith(s.backupError!)
                      : t.backupFolderLast(
                          s.backupFolderLabel,
                          formatDate(s.lastBackup),
                        ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _open(context, const AutoBackupScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: Text(t.accountCheck),
                subtitle: Text(t.accountCheckHint),
                onTap: () => _open(context, const AccountCheckScreen()),
              ),
              if (account.isAdmin) ...[
                SectionTitle(t.sectionServer),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: Text(t.administration),
                  subtitle: Text(t.administrationHint),
                  onTap: () => _open(context, const AdminScreen()),
                ),
              ],
              SectionTitle(t.sectionAccount),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(t.signOut),
                subtitle: Text(t.signOutHint),
                onTap: () async {
                  final ok = await confirm(
                    context,
                    title: t.signOutQuestion,
                    message: t.signOutMessage,
                    action: t.signOut,
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
                  t.deleteAccount,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _deleteAccount(context),
              ),
              SectionTitle(t.sectionAbout),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) => ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Sixora'),
                  subtitle: Text(
                    '${t.serverVersion(snap.data?.version ?? '…')}\n'
                    '${t.aboutText}',
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
        title: Text(t.changeMasterPassword),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PasswordField(
                controller: current,
                label: t.currentPassword,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: next,
                label: t.newPassword,
                autofillHints: const [AutofillHints.newPassword],
                helper: t.newPasswordHint,
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: repeat,
                label: t.repeatNewPassword,
                autofillHints: const [AutofillHints.newPassword],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.change),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (next.text.length < 10) {
      showMessage(context, t.newPasswordTooShort);
      return;
    }
    if (next.text != repeat.text) {
      showMessage(context, t.newPasswordsDoNotMatch);
      return;
    }
    final done = await runBusy(context, () async {
      await c.changePassword(current.text, next.text);
      return true;
    }, message: t.changingPassword);
    if (done == true && context.mounted) {
      showMessage(context, t.masterPasswordChanged);
    }
  }

  Future<void> _renewRecovery(BuildContext context) async {
    final c = AppScope.read(context);
    final password = await askText(
      context,
      title: t.newRecoveryKey,
      message: t.newRecoveryKeyConfirm,
      label: t.masterPassword,
      password: true,
      action: t.generate,
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
      title: t.deleteAccountQuestion,
      message: t.deleteAccountMessage,
      action: t.continueAction,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final password = await askText(
      context,
      title: t.confirmMasterPassword,
      label: t.masterPassword,
      password: true,
      action: t.deleteAccount,
    );
    if (password == null || !context.mounted) return;
    await runBusy(context, () => c.deleteAccount(password));
  }

  Future<void> _export(BuildContext context) async {
    final c = AppScope.read(context);
    final entries = [for (final i in c.items) i.entry];
    if (entries.isEmpty) {
      showMessage(context, t.nothingToExport);
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
              title: Text(t.encryptedBackup),
              subtitle: Text(t.encryptedBackupHint),
              onTap: () => Navigator.pop(context, 'backup'),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(t.googleAuthenticatorQr),
              subtitle: Text(t.googleAuthenticatorQrHint),
              onTap: () => Navigator.pop(context, 'qr'),
            ),
            ListTile(
              leading: Icon(
                Icons.warning_amber,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(t.plainTextFile),
              subtitle: Text(t.plainTextFileHint),
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
          message: t.encryptingBackup,
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
          title: t.exportUnencryptedQuestion,
          message: t.exportUnencryptedMessage,
          action: t.exportAction,
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
        dialogTitle: t.saveAs,
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(text)),
        mimeType: mime,
      );
      if (uri != null && context.mounted) showMessage(context, t.saved);
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
      title: Text(t.openOtpauthLinks),
      subtitle: Text(
        state.isDefault
            ? t.otpauthLinksOpenSixora
            : state.app.isEmpty
            ? t.linksOpenOtherApp
            : t.linksOpenApp(state.app),
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
                      t.notChanged(
                        e is PlatformException ? e.message ?? e.code : e,
                      ),
                    );
                  }
                }
                await _load();
              },
              child: Text(t.useSixora),
            ),
    );
  }
}
