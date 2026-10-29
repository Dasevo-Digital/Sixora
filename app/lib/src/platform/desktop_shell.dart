import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:sixora_core/sixora_core.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../data/app_controller.dart';
import '../l10n.dart';
import 'secure_clipboard.dart';

/// Menu bar (macOS) and notification area (Windows, Linux) icon with a
/// global shortcut: codes without opening the window.
///
/// * The menu copies the code of a favourite (up to ten) – the code itself
///   never appears in the menu. Everything else is a search away.
/// * „Suchen …“ and ⌥⌘O (macOS) / Strg+Alt+O bring the window to the front
///   with the search field focused.
/// * Closing the window keeps Sixora running in the menu bar, if wanted.
class DesktopShell with WindowListener {
  DesktopShell._(this.c);

  static DesktopShell? instance;

  /// Ticks when the window should open with the search field focused.
  static final focusSearch = ValueNotifier<int>(0);

  /// Global shortcut: macOS and Windows. Linux has none (Wayland offers
  /// no global key grabs to apps; see third_party/hotkey_manager_linux).
  static bool get hasShortcut => Platform.isMacOS || Platform.isWindows;

  static bool get supported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  final AppController c;
  String _menuState = '';
  HotKey? _hotKey;
  TrayIcon? _trayIcon;
  Image? _trayImage;
  Menu? _menu;
  List<MenuItem> _menuItems = const [];
  ListenerId? _trayListener;

  static String? _menuLanguage;

  /// macOS: the app menu (MainMenu.xib, German) follows the app language.
  static void setMenuLanguage(String code) {
    if (!Platform.isMacOS || code == _menuLanguage) return;
    _menuLanguage = code;
    const MethodChannel(
      'sixora/menu',
    ).invokeMethod<void>('setLanguage', code).catchError((_) {});
  }

  static String get shortcutLabel =>
      Platform.isMacOS ? '⌥⌘O' : t.shortcutCtrlAltO;

  static Future<void> start(AppController c) async {
    if (!supported || instance != null) return;
    final shell = DesktopShell._(c);
    instance = shell;
    try {
      await windowManager.ensureInitialized();
      windowManager.addListener(shell);
      await windowManager.setPreventClose(c.settings.keepInTray);
      final tray = TrayIcon.createWithIdentifier('de.status403.sixora');
      if (tray == null) throw StateError('Menüleistensymbol nicht verfügbar');
      shell._trayIcon = tray;
      final image = ImageAsset.fromAsset(
        Platform.isMacOS
            ? 'assets/tray/tray_template.png'
            : Platform.isWindows
            ? 'assets/tray/tray.ico'
            : 'assets/tray/tray.png',
      );
      if (image == null) throw StateError('Menüleistensymbol fehlt');
      shell._trayImage = image;
      tray
        ..icon = image
        ..isIconTemplate = Platform.isMacOS
        ..setTooltip(Platform.isLinux ? null : 'Sixora')
        ..setContextMenuTrigger(
          Platform.isMacOS
              ? ContextMenuTrigger.clicked
              : ContextMenuTrigger.rightClicked,
        );
      shell._trayListener = tray.addListener(shell._onTrayEvent);
      c.addListener(shell._changed);
      await shell._updateMenu();
      tray.setVisible(true);
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
    if (!c.settings.globalHotkey || !hasShortcut) return;
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
    c.removeListener(_changed);
    final tray = _trayIcon;
    final listener = _trayListener;
    if (tray != null && listener != null) tray.removeListener(listener);
    tray?.setContextMenu(null);
    for (final item in _menuItems) {
      item.dispose();
    }
    _menu?.dispose();
    tray?.setVisible(false);
    tray?.dispose();
    _trayImage?.dispose();
    _trayIcon = null;
    _trayImage = null;
    _menu = null;
    _menuItems = const [];
    await windowManager.destroy();
  }

  /// Entries in the menu: favourites only, at most ten, no counters.
  List<Item> get _quick => c.items
      .where((i) => i.entry.favorite && i.entry.type != OtpType.hotp)
      .take(10)
      .toList();

  void _changed() {
    // Rebuild the menu only when what it shows changes.
    final state =
        '${t.localeName}|${c.phase}|${[for (final i in _quick) '${i.id}:${i.entry.displayName}'].join(',')}';
    if (state == _menuState) return;
    _menuState = state;
    unawaited(_updateMenu());
  }

  Future<void> _updateMenu() async {
    final unlocked = c.phase == Phase.unlocked;
    final quick = unlocked ? _quick : const <Item>[];
    final menu = Menu.create();
    if (menu == null) throw StateError('Menü nicht verfügbar');
    final items = <MenuItem>[];
    MenuItem add(String label, String key, {bool enabled = true}) {
      final item = MenuItem.createWithLabelAndType(label, MenuItemType.normal);
      if (item == null) throw StateError('Menüeintrag nicht verfügbar');
      item.isEnabled = enabled;
      item.addListener((event) {
        if (event is MenuItemClickedEvent) _onMenuItem(key);
      });
      menu.addItem(item);
      items.add(item);
      return item;
    }

    add(t.openSixora, 'open');
    if (unlocked) {
      add(
        hasShortcut ? t.searchWithShortcut(shortcutLabel) : t.searchEllipsis,
        'search',
      );
      menu.addSeparator();
      if (quick.isEmpty) {
        add(t.favoritesHint, '', enabled: false);
      } else {
        add(t.copyCode, '', enabled: false);
        for (final item in quick) {
          add(
            '${item.entry.displayName}'
                '${item.entry.issuer.isNotEmpty && item.entry.account.isNotEmpty ? ' (${item.entry.account})' : ''}',
            'copy:${item.id}',
          );
        }
      }
      menu.addSeparator();
      add(t.lock, 'lock');
    } else if (c.phase == Phase.locked) {
      add(t.unlockEllipsis, 'open');
    }
    menu.addSeparator();
    add(t.quitSixora, 'quit');

    final oldMenu = _menu;
    final oldItems = _menuItems;
    _trayIcon?.setContextMenu(menu);
    _menu = menu;
    _menuItems = items;
    for (final item in oldItems) {
      item.dispose();
    }
    oldMenu?.dispose();
  }

  void _onTrayEvent(TrayIconEvent event) {
    switch (event) {
      case TrayIconClickedEvent():
        if (!Platform.isMacOS) unawaited(show());
      case TrayIconRightClickedEvent():
        if (Platform.isMacOS) _trayIcon?.openContextMenu();
      case TrayIconDoubleClickedEvent():
        if (!Platform.isMacOS) unawaited(show());
    }
  }

  void _onMenuItem(String key) {
    switch (key) {
      case 'open':
        unawaited(show());
      case 'search':
        unawaited(show(search: true));
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
