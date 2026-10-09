import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_controller.dart';
import 'data/local_store.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/welcome_screen.dart';
import 'widgets/common.dart';

const brandColor = Color(0xFF4F46E5);

class SixoraApp extends StatefulWidget {
  const SixoraApp({super.key, required this.controller});
  final AppController controller;

  @override
  State<SixoraApp> createState() => _SixoraAppState();
}

class _SixoraAppState extends State<SixoraApp> {
  static const _window = MethodChannel('sixora/window');
  static const _privacy = MethodChannel('sixora/privacy');
  final _navigator = GlobalKey<NavigatorState>();
  late final AppLifecycleListener _lifecycle;
  AppController get c => widget.controller;
  Phase _phase = Phase.loading;
  DateTime? _backgroundSince;
  Timer? _idle;

  /// Covers the codes while the app switcher shows a preview (mobile).
  bool _obscured = false;
  bool? _secureWindow;

  @override
  void initState() {
    super.initState();
    _phase = c.phase;
    c.addListener(_changed);
    _lifecycle = AppLifecycleListener(onStateChange: _lifecycleChanged);
    _applySecureWindow();
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    _lifecycle.dispose();
    _idle?.cancel();
    super.dispose();
  }

  void _changed() {
    if (c.phase != _phase) {
      // Locking or logging out closes every open page.
      if (_phase == Phase.unlocked) {
        _navigator.currentState?.popUntil((r) => r.isFirst);
      }
      _phase = c.phase;
      _resetIdle();
    }
    _applySecureWindow();
    setState(() {});
  }

  /// Android: no screenshots or screen recordings of the codes (FLAG_SECURE),
  /// unless the user allows them.
  void _applySecureWindow() {
    if (!Platform.isAndroid) return;
    final secure = !c.settings.allowScreenshots;
    if (secure == _secureWindow) return;
    _secureWindow = secure;
    _window.invokeMethod('setSecure', secure).catchError((_) => null);
  }

  bool get _mobile => Platform.isAndroid || Platform.isIOS;

  void _lifecycleChanged(AppLifecycleState state) {
    final autoLock = c.settings.autoLock;
    switch (state) {
      case AppLifecycleState.inactive:
        if (_mobile && c.phase == Phase.unlocked) {
          setState(() => _obscured = true);
        }
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _backgroundSince ??= DateTime.now();
        if (autoLock == AutoLock.immediately) c.lock();
        // Phones suspend apps in the background: no connection kept open.
        if (_mobile) c.pauseSync();
      case AppLifecycleState.resumed:
        final since = _backgroundSince;
        _backgroundSince = null;
        if (since != null &&
            autoLock != AutoLock.never &&
            DateTime.now().difference(since).inMinutes >= autoLock.minutes) {
          c.lock();
        } else if (since != null) {
          c.resumeSync();
        }
        setState(() => _obscured = false);
        _resetIdle();
        _uncoverWhenDrawn();
      case AppLifecycleState.detached:
        break;
    }
  }

  /// iOS: the native cover (see AppDelegate) goes once the current state –
  /// after a lock the lock screen – has been drawn.
  void _uncoverWhenDrawn() {
    if (!Platform.isIOS) return;
    WidgetsBinding.instance.endOfFrame.then((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await _privacy.invokeMethod<void>('uncover').catchError((_) => null);
    });
  }

  /// Locks after the auto-lock time without any input, also while the app
  /// stays in the foreground (e.g. a desktop left alone).
  void _resetIdle() {
    _idle?.cancel();
    final minutes = c.settings.autoLock.minutes;
    if (c.phase != Phase.unlocked || minutes < 0) return;
    _idle = Timer(Duration(minutes: minutes == 0 ? 1 : minutes), c.lock);
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final home = switch (c.phase) {
      Phase.loading => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      Phase.setup => const WelcomeScreen(),
      Phase.locked => const LockScreen(),
      Phase.unlocked => const HomeScreen(),
    };
    return AppScope(
      controller: c,
      child: Listener(
        onPointerDown: (_) => _resetIdle(),
        onPointerSignal: (_) => _resetIdle(),
        child: Focus(
          onKeyEvent: (_, _) {
            _resetIdle();
            return KeyEventResult.ignored;
          },
          child: MaterialApp(
            navigatorKey: _navigator,
            title: 'Sixora',
            debugShowCheckedModeBanner: false,
            theme: _theme(Brightness.light),
            darkTheme: _theme(Brightness.dark),
            themeMode: switch (c.settings.themeMode) {
              'light' => ThemeMode.light,
              'dark' => ThemeMode.dark,
              _ => ThemeMode.system,
            },
            locale: const Locale('de'),
            supportedLocales: const [Locale('de'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: KeyedSubtree(key: ValueKey(c.phase), child: home),
            builder: (context, child) => Stack(
              children: [
                ?child,
                if (_obscured)
                  const Positioned.fill(
                    child: ColoredBox(color: brandColor, child: _Shield()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Shield extends StatelessWidget {
  const _Shield();
  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(Icons.shield_outlined, size: 96, color: Colors.white),
  );
}
