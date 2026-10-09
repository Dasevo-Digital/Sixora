import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:sixora_core/sixora_core.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../data/app_controller.dart';
import 'secure_clipboard.dart';

/// Menu bar (macOS) and notification area (Windows, Linux) icon with a
/// global shortcut: codes without opening the window.
///
/// * The menu copies the code of a favourite (up to ten accounts) – the
///   code itself never appears in the menu.
/// * ⌥⌘O (macOS) / Strg+Alt+O brings the window to the front with the
///   search field focused.
/// * Closing the window keeps Sixora running in the menu bar, if wanted.
class DesktopShell with TrayListener, WindowListener {
  DesktopShell._(this.c);

  static DesktopShell? instance;

  /// Ticks when the window should open with the search field focused.
  static final focusSearch = ValueNotifier<int>(0);

  static bool get supported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  final AppController c;
  String _menuState = '';
  HotKey? _hotKey;

  static String get shortcutLabel => Platform.isMacOS ? '⌥⌘O' : 'Strg+Alt+O';

  static Future<void> start(AppController c) async {
    if (!supported || instance != null) return;
    final shell = DesktopShell._(c);
    instance = shell;
    try {
      await windowManager.ensureInitialized();
      windowManager.addListener(shell);
      await windowManager.setPreventClose(c.settings.keepInTray);
      await trayManager.setIcon(
        Platform.isMacOS
            ? 'assets/tray/tray_template.png'
            : Platform.isWindows
            ? 'assets/tray/tray.ico'
            : 'assets/tray/tray.png',
        isTemplate: true,
      );
      if (!Platform.isLinux) await trayManager.setToolTip('Sixora');
      trayManager.addListener(shell);
      c.addListener(shell._changed);
      await shell._updateMenu();
      await shell.applySettings();
    } on Object catch (e) {
      debugPrint('Menüleiste nicht verfügbar: $e');
    }
  }

  /// After a change of [AppSettings.keepInTray] or [AppSettings.globalHotkey].
  Future<void> applySettings() async {
    await windowManager.setPreventClose(c.settings.keepInTray);
    if (_hotKey != null) {
      await hotKeyManager.unregister(_hotKey!);
      _hotKey = null;
    }
    if (!c.settings.globalHotkey) return;
    final key = HotKey(
      key: PhysicalKeyboardKey.keyO,
      modifiers: Platform.isMacOS
          ? [HotKeyModifier.alt, HotKeyModifier.meta]
          : [HotKeyModifier.control, HotKeyModifier.alt],
      scope: HotKeyScope.system,
    );
    try {
      await hotKeyManager.register(
        key,
        keyDownHandler: (_) => show(search: true),
      );
      _hotKey = key;
    } on Object catch (e) {
      debugPrint('Tastenkürzel nicht verfügbar: $e');
    }
  }

  Future<void> show({bool search = false}) async {
    await windowManager.show();
    await windowManager.focus();
    if (search) focusSearch.value++;
  }

  Future<void> quit() async {
    await windowManager.setPreventClose(false);
    await hotKeyManager.unregisterAll();
    await trayManager.destroy();
    await windowManager.destroy();
  }

  /// Entries in the menu: favourites first, at most ten, no counters.
  List<Item> get _quick {
    final list = c.items.where((i) => i.entry.type != OtpType.hotp).toList();
    list.sort((a, b) {
      if (a.entry.favorite != b.entry.favorite) {
        return a.entry.favorite ? -1 : 1;
      }
      return 0;
    });
    return list.take(10).toList();
  }

  void _changed() {
    // Rebuild the menu only when what it shows changes.
    final state =
        '${c.phase}|${[for (final i in _quick) '${i.id}:${i.entry.displayName}'].join(',')}';
    if (state == _menuState) return;
    _menuState = state;
    unawaited(_updateMenu());
  }

  Future<void> _updateMenu() async {
    final unlocked = c.phase == Phase.unlocked;
    final quick = unlocked ? _quick : const <Item>[];
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'open', label: 'Sixora öffnen ($shortcutLabel)'),
          MenuItem.separator(),
          if (unlocked) ...[
            if (quick.isEmpty)
              MenuItem(label: 'Noch keine Konten', disabled: true)
            else
              for (final item in quick)
                MenuItem(
                  key: 'copy:${item.id}',
                  label:
                      'Code kopieren: ${item.entry.displayName}'
                      '${item.entry.issuer.isNotEmpty && item.entry.account.isNotEmpty ? ' (${item.entry.account})' : ''}',
                ),
            MenuItem.separator(),
            MenuItem(key: 'lock', label: 'Sperren'),
          ] else if (c.phase == Phase.locked)
            MenuItem(key: 'open', label: 'Entsperren …'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Sixora beenden'),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() {
    // macOS: a click opens the menu; elsewhere it shows the window.
    if (Platform.isMacOS) {
      trayManager.popUpContextMenu();
    } else {
      unawaited(show());
    }
  }

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key ?? '';
    switch (key) {
      case 'open':
        unawaited(show());
      case 'lock':
        c.lock();
      case 'quit':
        unawaited(quit());
      default:
        if (key.startsWith('copy:')) unawaited(_copy(key.substring(5)));
    }
  }

  Future<void> _copy(String id) async {
    final item = c.items.where((i) => i.id == id).firstOrNull;
    if (item == null || c.phase != Phase.unlocked) return;
    final code = item.entry.code();
    final clear = c.settings.clearClipboard;
    await SecureClipboard.copy(
      code,
      expiresIn: clear ? const Duration(seconds: 30) : Duration.zero,
    );
    if (clear && !SecureClipboard.expiresBySystem) {
      Timer(const Duration(seconds: 30), () async {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (current?.text == code) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      });
    }
  }

  @override
  void onWindowClose() {
    // Keep running in the menu bar: hide instead of quitting.
    if (c.settings.keepInTray) {
      unawaited(windowManager.hide());
    } else {
      unawaited(quit());
    }
  }
}
