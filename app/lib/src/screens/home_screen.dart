import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sixora_core/sixora_core.dart';

import '../data/app_controller.dart';
import '../data/error_texts.dart';
import '../l10n.dart';
import '../platform/desktop_shell.dart';
import '../platform/link_inbox.dart';
import '../platform/qr_image.dart';
import '../platform/screen_capture.dart';
import '../widgets/common.dart';
import '../widgets/otp_tile.dart';
import 'entry_editor.dart';
import 'entry_qr_screen.dart';
import 'import_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

enum _Filter { all, favorites, vault, group }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ticker = Ticker();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  _Filter _filter = _Filter.all;
  String? _filterValue;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    LinkInbox.instance.addListener(_takeLink);
    DesktopShell.focusSearch.addListener(_focusSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _offerBiometrics();
      _takeLink();
    });
  }

  /// The global shortcut: straight into the search field.
  void _focusSearch() {
    if (!mounted) return;
    _search.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _search.text.length,
    );
    _searchFocus.requestFocus();
  }

  /// A 2FA link (otpauth://, Google transfer) that opened the app.
  void _takeLink() {
    if (!mounted) return;
    final link = LinkInbox.instance.take(
      (l) => OtpAuthUri.looksLike(l) || GoogleMigration.looksLike(l),
    );
    if (link != null) _handleCode(link);
  }

  /// After an unlock with the password: offer Face ID & co. once.
  Future<void> _offerBiometrics() async {
    final c = AppScope.read(context);
    if (!c.offerBiometrics) return;
    c.offerBiometrics = false;
    final label = c.biometricLabel;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(biometricIcon(label), size: 40),
        title: Text(t.offerBiometricsTitle(label)),
        content: Text(t.offerBiometricsMessage(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.setUp),
          ),
        ],
      ),
    );
    if (!mounted) return;
    try {
      if (yes == true) {
        if (await c.setQuickUnlock(true) && mounted) {
          showMessage(context, t.biometricsEnabled(label));
        }
      } else {
        c.settings.biometricsOffered = true;
        await c.saveSettings();
        if (mounted) {
          showMessage(context, t.setUpLaterInSettings);
        }
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  void dispose() {
    LinkInbox.instance.removeListener(_takeLink);
    DesktopShell.focusSearch.removeListener(_focusSearch);
    _ticker.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Item> _visible(AppController c) {
    final query = _search.text.trim().toLowerCase();
    return c.items.where((i) {
      final e = i.entry;
      final match = switch (_filter) {
        _Filter.all => true,
        _Filter.favorites => e.favorite,
        _Filter.vault => i.vaultId == _filterValue,
        _Filter.group => e.group == _filterValue,
      };
      if (!match) return false;
      if (query.isEmpty) return true;
      return e.issuer.toLowerCase().contains(query) ||
          e.account.toLowerCase().contains(query) ||
          e.group.toLowerCase().contains(query) ||
          e.notes.toLowerCase().contains(query);
    }).toList();
  }

  void _copyFirst(AppController c) {
    final list = _visible(c);
    if (list.isEmpty) return;
    try {
      copySecret(
        context,
        list.first.entry.code(),
        what: t.codeFor(list.first.entry.displayName),
      );
    } on FormatException {
      // invalid secret, nothing to copy
    }
  }

  // --- Adding ----------------------------------------------------------------

  bool get _hasCamera =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  Future<void> _add() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasCamera)
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: Text(t.scanQrCode),
                subtitle: Text(t.withCamera),
                onTap: () => Navigator.pop(context, 'scan'),
              ),
            if (ScreenCapture.supported)
              ListTile(
                leading: const Icon(Icons.screenshot_monitor_outlined),
                title: Text(t.qrFromScreen),
                subtitle: Text(ScreenCapture.hint),
                onTap: () => Navigator.pop(context, 'screen'),
              ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(t.qrFromImage),
              subtitle: Text(t.qrFromImageHint),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: Text(t.linkFromClipboard),
              subtitle: Text(t.linkFromClipboardHint),
              onTap: () => Navigator.pop(context, 'paste'),
            ),
            ListTile(
              leading: const Icon(Icons.keyboard_outlined),
              title: Text(t.enterManually),
              subtitle: Text(t.enterManuallyHint),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: Text(t.importAction),
              subtitle: Text(t.importHint),
              onTap: () => Navigator.pop(context, 'import'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'scan':
        final text = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const ScanScreen()),
        );
        if (text != null) await _handleCode(text);
      case 'image':
        await _fromImage();
      case 'screen':
        await _fromScreen();
      case 'paste':
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        await _handleCode(data?.text ?? '');
      case 'manual':
        await _openEditor();
      case 'import':
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const ImportScreen()),
        );
    }
  }

  Future<void> _fromImage() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: t.chooseQrImages,
      type: FileType.image,
    );
    if (files.isEmpty || !mounted) return;
    final codes = await runBusy(
      context,
      () => readQrCodes(files),
      message: files.length == 1
          ? t.searchingQr
          : t.searchingQrInImages(files.length),
    );
    if (codes == null || !mounted) return;
    if (codes.isEmpty) {
      showMessage(context, files.length == 1 ? t.noQrInImage : t.noQrInImages);
      return;
    }
    await _handleCode(codes.join('\n'));
  }

  Future<void> _fromScreen() async {
    final List<String>? codes;
    try {
      codes = await ScreenCapture.readQrCodes();
    } on Object catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (codes == null || !mounted) return;
    if (codes.isEmpty) {
      showMessage(context, t.noQrOnScreen);
      return;
    }
    await _handleCode(codes.join('\n'));
  }

  /// Text from a QR code or the clipboard.
  Future<void> _handleCode(String text) async {
    final input = text.trim();
    // Several codes (transfer series, several screenshots) go to the import.
    if (GoogleMigration.looksLike(input) || input.contains('\n')) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => ImportScreen(initialText: input)),
      );
    } else if (OtpAuthUri.looksLike(input)) {
      final OtpEntry entry;
      try {
        entry = OtpAuthUri.parse(input);
      } on FormatException catch (e) {
        showMessage(context, t.linkIncomplete(coreErrorText(e.message)));
        return;
      }
      await _openEditor(initial: entry);
    } else {
      showMessage(context, t.notA2faLink);
    }
  }

  Future<void> _openEditor({OtpEntry? initial, Item? item}) async {
    final c = AppScope.read(context);
    if (c.writableVaults.isEmpty) {
      showMessage(context, t.noWritableVault);
      return;
    }
    if (initial != null && item == null && c.isDuplicate(initial)) {
      final go = await confirm(
        context,
        title: t.alreadyThere,
        message: t.alreadyThereMessage,
        action: t.addAnyway,
      );
      if (!go || !mounted) return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditor(
          initial: initial,
          item: item,
          defaultVaultId: _filter == _Filter.vault ? _filterValue : null,
          defaultGroup: _filter == _Filter.group ? _filterValue : null,
        ),
      ),
    );
  }

  // --- Entry actions -----------------------------------------------------------

  Future<void> _menu(Item item, Offset? position) async {
    final c = AppScope.read(context);
    final vault = c.vault(item.vaultId);
    final canWrite = vault?.canWrite ?? false;
    final actions = <(String, IconData, String)>[
      ('copy', Icons.copy, t.copyCode),
      if (canWrite) ('edit', Icons.edit_outlined, t.edit),
      if (canWrite)
        (
          'favorite',
          item.entry.favorite ? Icons.star_outline : Icons.star_rounded,
          item.entry.favorite ? t.removeFavorite : t.makeFavorite,
        ),
      if (canWrite && c.writableVaults.length > 1)
        ('move', Icons.drive_file_move_outline, t.moveToVault),
      ('qr', Icons.qr_code_2, t.transferQr),
      if (canWrite) ('delete', Icons.delete_outline, t.delete),
    ];
    String? choice;
    if (position != null) {
      choice = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx,
          position.dy,
        ),
        items: [
          for (final (id, icon, label) in actions)
            PopupMenuItem(
              value: id,
              child: ListTile(
                leading: Icon(icon),
                title: Text(label),
                dense: true,
              ),
            ),
        ],
      );
    } else {
      choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: EntryAvatar(item.entry, size: 36),
                title: Text(item.entry.displayName),
                subtitle: Text(
                  [
                    item.entry.account,
                    ?vault?.name,
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
              ),
              const Divider(),
              for (final (id, icon, label) in actions)
                ListTile(
                  leading: Icon(icon),
                  title: Text(label),
                  onTap: () => Navigator.pop(context, id),
                ),
            ],
          ),
        ),
      );
    }
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'copy':
        await copySecret(context, item.entry.code());
      case 'edit':
        await _openEditor(item: item);
      case 'favorite':
        await runBusy(context, () => c.toggleFavorite(item));
      case 'move':
        await _move(item);
      case 'qr':
        final ok = await confirm(
          context,
          title: t.showSecretQuestion,
          message: t.showSecretMessage,
          action: t.show,
        );
        if (ok && mounted) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => EntryQrScreen(entries: [item.entry]),
            ),
          );
        }
      case 'delete':
        final ok = await confirm(
          context,
          title: t.deleteEntryQuestion(item.entry.displayName),
          message: vault?.shared == true
              ? t.deleteEntrySharedMessage
              : t.deleteEntryMessage,
          action: t.delete,
          destructive: true,
        );
        if (ok && mounted) {
          final done = await runBusy(context, () async {
            await c.deleteEntry(item);
            return true;
          });
          if (done == true && mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  // With an action, Flutter keeps it until tapped otherwise.
                  persist: false,
                  duration: const Duration(seconds: 6),
                  content: Text(t.entryDeleted(item.entry.displayName)),
                  action: SnackBarAction(
                    label: t.undo,
                    onPressed: () => runBusy(context, () async {
                      final trash = await c.trash();
                      final hit = trash.where((x) => x.item.id == item.id);
                      if (hit.isNotEmpty) await c.restore(hit.first);
                    }),
                  ),
                ),
              );
          }
        }
    }
  }

  Future<void> _move(Item item) async {
    final c = AppScope.read(context);
    final target = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(t.moveTo),
        children: [
          for (final v in c.writableVaults)
            if (v.id != item.vaultId)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, v.id),
                child: ListTile(
                  leading: Icon(
                    v.shared ? Icons.group_outlined : Icons.lock_outline,
                  ),
                  title: Text(v.name),
                ),
              ),
        ],
      ),
    );
    if (target != null && mounted) {
      await runBusy(context, () => c.moveEntry(item, target));
    }
  }

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final theme = Theme.of(context);
    final visible = _visible(c);
    final multiVault = c.vaults.length > 1;
    final groups = c.groups;
    if (_filter == _Filter.group && !groups.contains(_filterValue) ||
        _filter == _Filter.vault && c.vault(_filterValue ?? '') == null) {
      _filter = _Filter.all;
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true): c.lock,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): c.lock,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _add,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _add,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            title: _SearchField(
              controller: _search,
              focusNode: _searchFocus,
              onSubmitted: (_) => _copyFirst(c),
            ),
            actions: [
              if (c.syncing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: t.synchronize,
                  icon: Icon(
                    c.syncError == null ? Icons.sync : Icons.sync_problem,
                  ),
                  onPressed: c.sync,
                ),
              IconButton(
                tooltip: t.lock,
                icon: const Icon(Icons.lock_outline),
                onPressed: c.lock,
              ),
              IconButton(
                tooltip: t.settings,
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: Text(t.add),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  if (c.items.isNotEmpty &&
                      (groups.isNotEmpty ||
                          multiVault ||
                          c.items.any((i) => i.entry.favorite)))
                    SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        children: [
                          _chip(t.all, _Filter.all, null),
                          if (c.items.any((i) => i.entry.favorite))
                            _chip(
                              t.favorites,
                              _Filter.favorites,
                              null,
                              icon: Icons.star_rounded,
                            ),
                          if (multiVault)
                            for (final v in c.vaults)
                              _chip(
                                v.name,
                                _Filter.vault,
                                v.id,
                                icon: v.shared
                                    ? Icons.group_outlined
                                    : Icons.lock_outline,
                              ),
                          for (final g in groups)
                            _chip(
                              g,
                              _Filter.group,
                              g,
                              icon: Icons.folder_outlined,
                            ),
                        ],
                      ),
                    ),
                  if (c.securityWarning != null)
                    _Banner(icon: Icons.gpp_bad, text: c.securityWarning!),
                  for (final session in c.unknownSessions)
                    _SignInNotice(session: session),
                  if (c.syncError != null)
                    _Banner(
                      icon: Icons.cloud_off,
                      text: t.syncErrorBanner(c.syncError!),
                    ),
                  if (c.undecryptable > 0)
                    _Banner(
                      icon: Icons.warning_amber,
                      text: t.undecryptableEntries(c.undecryptable),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: c.sync,
                      child: c.items.isEmpty
                          ? _empty(theme)
                          : visible.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(height: 80),
                                Center(child: Text(t.noMatches)),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(
                                top: 4,
                                bottom: 96,
                              ),
                              itemCount: visible.length,
                              itemBuilder: (context, i) {
                                final item = visible[i];
                                return OtpTile(
                                  key: ValueKey(item.id),
                                  item: item,
                                  ticker: _ticker,
                                  vaultName:
                                      multiVault && _filter != _Filter.vault
                                      ? c.vault(item.vaultId)?.name
                                      : null,
                                  onMenu: (pos) => _menu(item, pos),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, _Filter filter, String? value, {IconData? icon}) {
    final selected =
        _filter == filter && (_filterValue == value || value == null);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: icon == null ? null : Icon(icon, size: 18),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() {
          _filter = filter;
          _filterValue = value;
        }),
      ),
    );
  }

  Widget _empty(ThemeData theme) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      const SizedBox(height: 48),
      Icon(Icons.qr_code_2, size: 72, color: theme.colorScheme.primary),
      const SizedBox(height: 16),
      Text(
        t.noAccountsYet,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        t.noAccountsHint,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 24),
      Center(
        child: FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: Text(t.addAccount),
        ),
      ),
    ],
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: t.search,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: t.clear,
                icon: const Icon(Icons.close),
                onPressed: controller.clear,
              ),
        filled: true,
        contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}

/// Another device signed in to this account: either the user on a new
/// device or somebody who knows the master password.
class _SignInNotice extends StatefulWidget {
  const _SignInNotice({required this.session});
  final SessionDto session;

  @override
  State<_SignInNotice> createState() => _SignInNoticeState();
}

class _SignInNoticeState extends State<_SignInNotice> {
  bool _busy = false;

  Future<void> _signOut() async {
    final c = AppScope.read(context);
    final ok = await confirm(
      context,
      title: t.signOutDeviceQuestion,
      message: t.signOutDeviceMessage(widget.session.deviceName),
      action: t.signOut,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await c.revokeSession(widget.session.id);
      if (mounted) showMessage(context, t.deviceSignedOut);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = widget.session;
    final platform = s.platform.isEmpty ? '' : ' (${s.platform})';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices_other, color: scheme.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.newSignIn(
                      s.deviceName,
                      platform,
                      formatDate(s.createdAt),
                    ),
                    style: TextStyle(
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => AppScope.read(context).acknowledgeSession(s.id),
                    child: Text(t.thatWasMe),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _signOut,
                    child: Text(t.signOut),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      dense: true,
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
      title: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    ),
  );
}
