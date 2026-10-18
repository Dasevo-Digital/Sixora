import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Desktop: tells when the user steps away from the computer – the screen
/// locks, the computer goes to sleep, another user takes over – so Sixora
/// locks right then instead of after its idle time.
///
/// * macOS and Windows: the runner passes the system's notifications on as
///   `away` over the channel `sixora/session`.
/// * Linux: systemd-logind on the system bus (`LockedHint` and `Lock` of the
///   session, `PrepareForSleep`) and the screen saver on the session bus.
///   Without them Sixora stays with its idle timer.
class SessionEvents {
  SessionEvents(this.onAway);

  final void Function() onAway;

  static const _channel = MethodChannel('sixora/session');

  /// The instance the channel's calls go to (the newest one).
  static SessionEvents? _current;

  final _subscriptions = <StreamSubscription<Object?>>[];
  final _buses = <DBusClient>[];
  bool _stopped = false;

  Future<void> start() async {
    if (Platform.isMacOS || Platform.isWindows) {
      _current = this;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'away') _current?.onAway();
      });
    } else if (Platform.isLinux) {
      await _logind();
      _screenSaver();
    }
  }

  Future<void> stop() async {
    _stopped = true;
    if (identical(_current, this)) {
      _current = null;
      _channel.setMethodCallHandler(null);
    }
    final subscriptions = [..._subscriptions];
    final buses = [..._buses];
    _subscriptions.clear();
    _buses.clear();
    for (final s in subscriptions) {
      await s.cancel();
    }
    for (final b in buses) {
      await b.close();
    }
  }

  DBusClient? _bus(DBusClient Function() open) {
    if (_stopped) return null;
    final bus = open();
    _buses.add(bus);
    return bus;
  }

  void _watch<T>(Stream<T> stream, void Function(T) onEvent) {
    if (_stopped) return;
    _subscriptions.add(stream.listen(onEvent, onError: (Object _) {}));
  }

  Future<void> _logind() async {
    const name = 'org.freedesktop.login1';
    final bus = _bus(DBusClient.system);
    if (bus == null) return;
    try {
      final manager = DBusRemoteObject(
        bus,
        name: name,
        path: DBusObjectPath('/org/freedesktop/login1'),
      );
      _watch(
        DBusRemoteObjectSignalStream(
          object: manager,
          interface: '$name.Manager',
          name: 'PrepareForSleep',
          signature: DBusSignature('b'),
        ),
        (s) {
          if (s.values.first.asBoolean()) onAway();
        },
      );
      final session = DBusRemoteObject(
        bus,
        name: name,
        path: await _graphicalSession(manager),
      );
      _watch(
        DBusRemoteObjectSignalStream(
          object: session,
          interface: '$name.Session',
          name: 'Lock',
        ),
        (_) => onAway(),
      );
      // GNOME and KDE report their lock screen here.
      _watch(session.propertiesChanged, (s) {
        if (s.propertiesInterface == '$name.Session' &&
            s.changedProperties['LockedHint']?.asBoolean() == true) {
          onAway();
        }
      });
    } on Object catch (e) {
      debugPrint('logind nicht erreichbar: $e');
    }
  }

  /// The user's graphical session. Apps started from the desktop often run
  /// outside of it (in their own systemd scope), so "the caller's session"
  /// is not the one that gets locked.
  static Future<DBusObjectPath> _graphicalSession(
    DBusRemoteObject manager,
  ) async {
    const name = 'org.freedesktop.login1';
    try {
      final user = await manager.callMethod('$name.Manager', 'GetUserByPID', [
        DBusUint32(pid),
      ], replySignature: DBusSignature('o'));
      final display = await DBusRemoteObject(
        manager.client,
        name: name,
        path: user.values.first.asObjectPath(),
      ).getProperty('$name.User', 'Display', signature: DBusSignature('(so)'));
      final path = display.asStruct()[1].asObjectPath();
      if (path.value != '/') return path;
    } on DBusMethodResponseException {
      // Fall back to the caller's own session.
    }
    final own = await manager.callMethod('$name.Manager', 'GetSession', [
      const DBusString('auto'),
    ], replySignature: DBusSignature('o'));
    return own.values.first.asObjectPath();
  }

  void _screenSaver() {
    try {
      final bus = _bus(DBusClient.session);
      if (bus == null) return;
      for (final interface in [
        'org.freedesktop.ScreenSaver',
        'org.gnome.ScreenSaver',
      ]) {
        _watch(
          DBusSignalStream(
            bus,
            interface: interface,
            name: 'ActiveChanged',
            signature: DBusSignature('b'),
          ),
          (s) {
            if (s.values.first.asBoolean()) onAway();
          },
        );
      }
    } on Object catch (e) {
      debugPrint('Bildschirmschoner nicht erreichbar: $e');
    }
  }
}
