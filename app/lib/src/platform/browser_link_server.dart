import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sixora_core/sixora_core.dart';

import '../data/app_controller.dart';
import '../environment.dart';

/// Desktop: the app's end of "Mit Touch ID entsperren" in the browser
/// extension (see [BrowserLink]). While switched on, Sixora listens on
/// 127.0.0.1 and its native messaging host is registered with the browsers
/// ([NativeHosts]); the host only passes bytes between browser and app.
class BrowserLinkServer {
  BrowserLinkServer(this.host);

  static BrowserLinkServer? instance;

  final BrowserLinkHost host;
  ServerSocket? _socket;

  /// For tests: 0 picks a free port ([boundPort]).
  @visibleForTesting
  static int? portForTests;

  /// Sixora, Sixora Dev and the test build each have their own.
  static int get port =>
      portForTests ??
      switch (AppEnv.name) {
        'prod' => BrowserLink.ports[0],
        'dev' => BrowserLink.ports[1],
        _ => BrowserLink.ports[2],
      };

  bool get running => _socket != null;

  int? get boundPort => _socket?.port;

  /// Switches the link on or off. On: the browsers in which the host was
  /// registered; throws if the port is taken.
  Future<List<String>> setEnabled(bool enabled) async {
    if (!enabled) {
      await _socket?.close();
      _socket = null;
      await NativeHosts.remove();
      return const [];
    }
    if (_socket == null) {
      _socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      _socket!.listen(_serve);
    }
    return NativeHosts.install();
  }

  void _serve(Socket client) => serveLink(host, client);
}

/// Answers framed requests on [client] in order. When the other side is
/// done sending, open requests are still answered before it closes.
void serveLink(BrowserLinkHost host, Socket client) {
  // The socket listens on 127.0.0.1 only; this guards against mistakes.
  if (!client.remoteAddress.isLoopback) {
    client.destroy();
    return;
  }
  final reader = FrameReader();
  var pending = Future<void>.value();
  client.done.ignore();
  client.listen(
    (data) {
      final List<Map<String, Object?>> messages;
      try {
        messages = reader.add(data);
      } on FormatException {
        client.destroy();
        return;
      }
      for (final message in messages) {
        pending = pending.then((_) async {
          final reply = await host.handle(message);
          try {
            client.add(BrowserLink.frame(reply));
          } on Object {
            // The browser closed the port meanwhile.
          }
        });
      }
    },
    onError: (Object _) => client.destroy(),
    onDone: () => pending.whenComplete(client.close),
    cancelOnError: true,
  );
}

/// What the link knows about the app: account, lock state and how the user
/// confirms.
class AppLinkDelegate implements BrowserLinkDelegate {
  AppLinkDelegate(
    this.c, {
    required this.reason,
    required this.confirm,
    required this.confirmPairing,
  });

  final AppController c;

  /// Text for the Touch ID / Windows Hello dialog.
  final String Function(String browser) reason;

  /// Dialog in the app where there is no biometric check.
  final Future<bool> Function(String browser) confirm;

  /// Dialog in the app: connect this extension (showing its code)?
  final Future<bool> Function(String code, String browser) confirmPairing;

  @override
  ({Uri server, String userId})? get account {
    final cached = c.cached;
    if (cached == null || c.isLocal) return null;
    return (server: cached.server, userId: cached.account.id);
  }

  @override
  bool get unlocked => c.phase == Phase.unlocked;

  @override
  bool get unlockWhileLocked => c.phase == Phase.locked && c.quickUnlockReady;

  @override
  String? get method => c.biometricsAvailable ? c.biometricLabel : null;

  @override
  bool isPaired(String publicKey) => c.isLinkedBrowser(publicKey);

  @override
  Future<Uint8List?> approve({required String browser}) =>
      c.approveBrowserUnlock(
        reason: reason(browser),
        confirm: () => confirm(browser),
      );

  @override
  Future<Uint8List?> pair({
    required String publicKey,
    required String code,
    required String browser,
  }) => c.pairBrowser(
    publicKey: publicKey,
    browser: browser,
    confirm: () => confirmPairing(code, browser),
  );
}

/// Registers Sixora's native messaging host with the browsers: a manifest
/// that names the host program and the extension allowed to start it.
///
/// * macOS, Linux: a file in each installed browser's `NativeMessagingHosts`
///   folder (the macOS app may write there, see Release.entitlements).
/// * Windows: two files in the app's data folder and a registry key per
///   browser family pointing to them.
abstract final class NativeHosts {
  static String get _file => '${BrowserLink.hostName}.json';

  /// The program the browser starts: on macOS Sixora itself (it recognises
  /// the call before it opens a window), elsewhere `sixora-bridge` next to
  /// it (Windows starts hosts through cmd.exe).
  static String get program {
    final exe = Platform.resolvedExecutable;
    if (Platform.isMacOS) return exe;
    return p.join(
      p.dirname(exe),
      Platform.isWindows ? 'sixora-bridge.exe' : 'sixora-bridge',
    );
  }

  static Map<String, Object?> manifest({required bool firefox}) => {
    'name': BrowserLink.hostName,
    'description': 'Sixora',
    'path': program,
    'type': 'stdio',
    if (firefox)
      'allowed_extensions': [BrowserLink.firefoxId]
    else
      'allowed_origins': ['chrome-extension://${BrowserLink.chromiumId}/'],
  };

  /// For tests: a home folder of their own.
  @visibleForTesting
  static String? homeForTests;

  /// The user's home; inside the macOS sandbox HOME is the app's container.
  static String get home {
    if (homeForTests case final h?) return h;
    final h =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final i = h.indexOf('/Library/Containers/');
    return i >= 0 ? h.substring(0, i) : h;
  }

  /// Browser name, its folder (relative to [home]), the manifest folder in
  /// it, and whether it is Firefox.
  static List<(String, String, String, bool)> get _folders {
    if (Platform.isMacOS) {
      const support = 'Library/Application Support';
      return const [
        // Opera reads Chrome's folder too.
        (
          'Chrome, Opera',
          '$support/Google/Chrome',
          'NativeMessagingHosts',
          false,
        ),
        ('Chromium', '$support/Chromium', 'NativeMessagingHosts', false),
        ('Edge', '$support/Microsoft Edge', 'NativeMessagingHosts', false),
        (
          'Brave',
          '$support/BraveSoftware/Brave-Browser',
          'NativeMessagingHosts',
          false,
        ),
        ('Vivaldi', '$support/Vivaldi', 'NativeMessagingHosts', false),
        ('Firefox', '$support/Mozilla', 'NativeMessagingHosts', true),
      ];
    }
    return const [
      ('Chrome', '.config/google-chrome', 'NativeMessagingHosts', false),
      ('Chromium', '.config/chromium', 'NativeMessagingHosts', false),
      ('Edge', '.config/microsoft-edge', 'NativeMessagingHosts', false),
      (
        'Brave',
        '.config/BraveSoftware/Brave-Browser',
        'NativeMessagingHosts',
        false,
      ),
      ('Vivaldi', '.config/vivaldi', 'NativeMessagingHosts', false),
      ('Opera', '.config/opera', 'NativeMessagingHosts', false),
      ('Firefox', '.mozilla', 'native-messaging-hosts', true),
    ];
  }

  /// Windows: registry keys under HKCU\Software. Opera, Vivaldi and Brave
  /// read Chrome's.
  static const _registry = [
    (r'Google\Chrome', false),
    (r'Chromium', false),
    (r'Microsoft\Edge', false),
    (r'Mozilla', true),
  ];

  static Future<List<String>> install() async {
    if (Platform.isWindows) return _installWindows();
    final found = <String>[];
    for (final (name, browser, hosts, firefox) in _folders) {
      final dir = Directory(p.join(home, browser, hosts));
      try {
        // Only for installed browsers: without the browser's folder the
        // creation fails (and the sandbox allows only the hosts folder).
        await dir.create();
        await File(p.join(dir.path, _file)).writeAsString(
          const JsonEncoder.withIndent(
            '  ',
          ).convert(manifest(firefox: firefox)),
        );
        found.add(name);
      } on FileSystemException {
        continue;
      }
    }
    return found;
  }

  static Future<void> remove() async {
    if (Platform.isWindows) return _removeWindows();
    for (final (_, browser, hosts, _) in _folders) {
      final file = File(p.join(home, browser, hosts, _file));
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        continue;
      }
    }
  }

  static Directory get _windowsDir => Directory(
    p.join(
      Platform.environment['LOCALAPPDATA'] ?? home,
      'Sixora',
      'NativeMessaging',
    ),
  );

  static Future<List<String>> _installWindows() async {
    final dir = await _windowsDir.create(recursive: true);
    final files = {
      for (final firefox in [false, true])
        firefox: p.join(
          dir.path,
          '${BrowserLink.hostName}.${firefox ? 'firefox' : 'chromium'}.json',
        ),
    };
    for (final MapEntry(key: firefox, value: path) in files.entries) {
      await File(path).writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest(firefox: firefox)),
      );
    }
    for (final (key, firefox) in _registry) {
      await Process.run('reg', [
        'add',
        'HKCU\\Software\\$key\\NativeMessagingHosts\\${BrowserLink.hostName}',
        '/ve',
        '/t',
        'REG_SZ',
        '/d',
        files[firefox]!,
        '/f',
      ]);
    }
    return const ['Chrome', 'Edge', 'Opera', 'Brave', 'Vivaldi', 'Firefox'];
  }

  static Future<void> _removeWindows() async {
    for (final (key, _) in _registry) {
      await Process.run('reg', [
        'delete',
        'HKCU\\Software\\$key\\NativeMessagingHosts\\${BrowserLink.hostName}',
        '/f',
      ]);
    }
    try {
      if (await _windowsDir.exists()) await _windowsDir.delete(recursive: true);
    } on FileSystemException {
      // Left for the next time.
    }
  }

  /// For tests: the manifest folder of each browser under [home].
  @visibleForTesting
  static List<String> get folders => [
    for (final (_, browser, hosts, _) in _folders) p.join(browser, hosts),
  ];
}
