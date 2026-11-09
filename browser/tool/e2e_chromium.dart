// End-to-end test of the extension in a Chromium browser (Opera, or the
// one in CHROMIUM_APP), headless and with a throwaway profile:
//
//   tool/build.sh && dart run tool/e2e_chromium.dart
//
// The browser loads build/chromium unpacked and is driven over the
// DevTools protocol; the checks are in e2e/common.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sixora_core/sixora_core.dart';

import 'e2e/common.dart';
import 'e2e/passkeys.dart';

const _relatedApp = 'app.sixora-e2e.example';
const _relatedRp = 'rp.sixora-e2e.example';
const _unlistedRp = 'unlisted.sixora-e2e.example';

Future<void> main() async {
  final app =
      Platform.environment['CHROMIUM_APP'] ??
      '/Applications/Opera.app/Contents/MacOS/Opera';
  final work = Directory.systemTemp.createTempSync('sixora-e2e-');
  final server = await TestServer.start();
  final desktop = await FakeDesktopApp.start(server);
  // The native messaging host: Sixora itself on macOS (Sixora Dev here).
  final host =
      Platform.environment['SIXORA_HOST_BINARY'] ??
      '/Applications/Sixora Dev.app/Contents/MacOS/Sixora Dev';
  final hostManifest = File(
    '${Platform.environment['HOME']}/Library/Application Support/Google/'
    'Chrome/NativeMessagingHosts/${BrowserLink.hostName}.json',
  );
  final hostBackup = File('${hostManifest.path}.e2e-backup');
  Process? browser;
  HttpServer? secure;
  var failures = 0;
  try {
    // A copy whose host permission for the test server is already granted:
    // headless, nobody could answer the browser's question.
    final extension = Directory('${work.path}/extension');
    await Process.run('cp', ['-R', 'build/chromium', extension.path]);
    final manifest = File('${extension.path}/manifest.json');
    final json = (jsonDecode(manifest.readAsStringSync()) as Map)
      ..['host_permissions'] = [
        'http://127.0.0.1/*',
        // What switching passkeys on asks for.
        'https://*/*',
        'http://localhost/*',
      ];
    manifest.writeAsStringSync(jsonEncode(json));
    final path = extension.resolveSymbolicLinksSync();
    // Opera reads host manifests from Chrome's folder only (not from its
    // profile): the test's goes there for the run, an existing one comes
    // back afterwards.
    hostManifest.parent.createSync(recursive: true);
    if (hostManifest.existsSync()) hostManifest.renameSync(hostBackup.path);
    hostManifest.writeAsStringSync(
      jsonEncode({
        'name': BrowserLink.hostName,
        'description': 'Sixora',
        'path': host,
        'type': 'stdio',
        'allowed_origins': ['chrome-extension://${BrowserLink.chromiumId}/'],
      }),
    );
    // HTTPS under names of their own, for related origins.
    final tls = Directory('${work.path}/tls')..createSync();
    await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-days',
      '2',
      '-subj',
      '/CN=sixora-e2e',
      '-keyout',
      '${tls.path}/key.pem',
      '-out',
      '${tls.path}/cert.pem',
    ]);
    secure = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      SecurityContext()
        ..useCertificateChain('${tls.path}/cert.pem')
        ..usePrivateKey('${tls.path}/key.pem'),
    );
    secure.listen((request) {
      final response = request.response;
      if (request.uri.path != '/.well-known/webauthn') {
        response
          ..headers.contentType = ContentType.html
          ..write(passkeyTestPage);
      } else if (request.headers.host == _relatedRp) {
        response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'origins': ['https://$_relatedApp'],
            }),
          );
      } else {
        response.statusCode = HttpStatus.notFound;
      }
      response.close();
    });
    final port = 29300 + DateTime.now().millisecond % 500;
    browser = await Process.start(
      app,
      environment: {'SIXORA_LINK_PORT': '${desktop.port}'},
      [
        '--headless=new',
        '--remote-debugging-port=$port',
        '--user-data-dir=${work.path}/profile',
        '--load-extension=$path',
        '--ignore-certificate-errors',
        '--host-resolver-rules=${[
          for (final name in [_relatedApp, _relatedRp, _unlistedRp]) 'MAP $name:443 127.0.0.1:${secure.port}',
        ].join(',')}',
        '--disable-features=DisableLoadExtensionCommandLineSwitch,LocalNetworkAccessChecks',
        '--no-first-run',
        '--no-default-browser-check',
        'about:blank',
      ],
    );
    final cdp = await Cdp.connect(port);
    failures = await runScenario(
      cdp,
      'chrome-extension://${BrowserLink.chromiumId}',
      server.url,
      app: File(host).existsSync() ? desktop : null,
      // Chromium enforces a 30-second minimum for extension alarms. Firefox
      // also covers the separate "newer clipboard content" branch quickly.
      clipboardAlarmMinutes: 0.5,
      clipboardAlarmWait: const Duration(seconds: 31),
      checkClipboardPreservation: false,
    );
    failures += await runPasskeyScenario(
      cdp,
      'chrome-extension://${BrowserLink.chromiumId}',
      hasApp: File(host).existsSync(),
      realSwitchOff: false,
      serverOrigin: 'http://127.0.0.1/*',
      related: const RelatedSite(
        'https://$_relatedApp/',
        _relatedRp,
        _unlistedRp,
      ),
    );
    await cdp.close();
  } on Object catch (e) {
    stderr.writeln('FEHLER: $e');
    failures++;
  } finally {
    // Headless Chromium may ignore a polite request to quit.
    browser?.kill();
    await browser?.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        browser?.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    await secure?.close(force: true);
    await server.stop();
    await desktop.stop();
    if (hostManifest.existsSync()) hostManifest.deleteSync();
    if (hostBackup.existsSync()) hostBackup.renameSync(hostManifest.path);
    // The browser may still be writing its profile for a moment.
    for (var i = 0; i < 10 && work.existsSync(); i++) {
      try {
        work.deleteSync(recursive: true);
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }
  if (failures > 0) {
    stderr.writeln('$failures Prüfungen fehlgeschlagen');
    exit(1);
  }
  stdout.writeln('Alle Prüfungen bestanden.');
}

/// Chromium names an unpacked extension after its folder: SHA-256 of the
/// path, the first 32 hex digits written with the letters a–p.
/// A minimal DevTools protocol client for one tab.
class Cdp implements PasskeyDriver {
  Cdp._(this._socket) {
    _socket.listen((data) {
      final m = (jsonDecode(data as String) as Map).cast<String, Object?>();
      final id = m['id'];
      if (id is! int) return; // an event
      final done = _pending.remove(id);
      if (m['error'] != null) {
        done?.completeError(StateError(jsonEncode(m['error'])));
      } else {
        done?.complete(m['result']);
      }
    });
  }

  final WebSocket _socket;
  final _pending = <int, Completer<Object?>>{};
  var _id = 0;
  String? _session;

  static Future<Cdp> connect(int port) async {
    final end = DateTime.now().add(const Duration(seconds: 60));
    final client = HttpClient();
    while (true) {
      try {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/json/version'),
        );
        final body = await (await request.close())
            .transform(utf8.decoder)
            .join();
        final ws = (jsonDecode(body) as Map)['webSocketDebuggerUrl'] as String;
        final cdp = Cdp._(await WebSocket.connect(ws));
        final target =
            await cdp._send('Target.createTarget', {'url': 'about:blank'})
                as Map;
        final attached =
            await cdp._send('Target.attachToTarget', {
                  'targetId': target['targetId'],
                  'flatten': true,
                })
                as Map;
        cdp._session = attached['sessionId'] as String;
        client.close();
        return cdp;
      } on SocketException {
        if (DateTime.now().isAfter(end)) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<Object?> _send(
    String method, [
    Map<String, Object?> params = const {},
  ]) {
    if (Platform.environment['E2E_DEBUG'] != null) stderr.writeln('> $method');
    final id = ++_id;
    final done = _pending[id] = Completer<Object?>();
    _socket.add(
      jsonEncode({
        'id': id,
        'method': method,
        'params': params,
        'sessionId': ?_session,
      }),
    );
    return done.future.timeout(const Duration(seconds: 30));
  }

  Future<void> close() =>
      _socket.close().timeout(const Duration(seconds: 5), onTimeout: () {});

  String? _page;
  String? _passkeyTarget;

  /// Browser-wide, outside the session of a tab.
  Future<Object?> _browser(String method, Map<String, Object?> params) {
    final saved = _session;
    _session = null;
    final sent = _send(method, params);
    _session = saved;
    return sent;
  }

  Future<String?> get _passkeyWindow async {
    final r = await _browser('Target.getTargets', const {}) as Map;
    for (final t in r['targetInfos'] as List) {
      if ((t as Map)['url'].toString().contains('popup.html#passkey=')) {
        return t['targetId'] as String;
      }
    }
    return null;
  }

  @override
  Future<bool> get passkeyWindowOpen async => await _passkeyWindow != null;

  @override
  Future<void> toPasskeyWindow() async {
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (true) {
      final id = await _passkeyWindow;
      if (id != null) {
        final attached =
            await _browser('Target.attachToTarget', {
                  'targetId': id,
                  'flatten': true,
                })
                as Map;
        _page = _session;
        _passkeyTarget = id;
        _session = attached['sessionId'] as String;
        return;
      }
      if (DateTime.now().isAfter(end)) {
        throw StateError('Kein Passkey-Fenster');
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  Future<void> toPage() async => _session = _page;

  @override
  Future<void> closePasskeyWindow() =>
      _browser('Target.closeTarget', {'targetId': _passkeyTarget});

  @override
  Future<void> navigate(String url) async {
    await _send('Page.navigate', {'url': url});
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(end)) {
      final state = await script(
        'return location.href + " " + document.readyState;',
      );
      if (state == '$url complete') return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    throw StateError('$url lädt nicht');
  }

  @override
  Future<Object?> script(String body, [List<Object?> args = const []]) async {
    final r =
        await _send('Runtime.evaluate', {
              'expression':
                  '(async function () { $body }).apply(null, ${jsonEncode(args)})',
              'awaitPromise': true,
              'returnByValue': true,
              // Counts as a click: browsers ask for permissions only then.
              'userGesture': true,
            })
            as Map;
    if (r['exceptionDetails'] case final Map details) {
      throw StateError(jsonEncode(details));
    }
    return (r['result'] as Map)['value'];
  }

  @override
  Future<void> type(String css, String text) => script(
    'const e = document.querySelector(arguments[0]); e.focus();'
    'e.value = arguments[1];'
    "e.dispatchEvent(new Event('input', {bubbles: true}));",
    [css, text],
  );

  @override
  Future<void> click(String css) =>
      script('document.querySelector(arguments[0]).click();', [css]);

  @override
  Future<void> trustedClick(String css) async {
    final center =
        await script(
              'const r = document.querySelector(arguments[0])'
              '.getBoundingClientRect();'
              'return [r.x + r.width / 2, r.y + r.height / 2];',
              [css],
            )
            as List;
    for (final type in ['mouseMoved', 'mousePressed', 'mouseReleased']) {
      await _send('Input.dispatchMouseEvent', {
        'type': type,
        'x': center[0],
        'y': center[1],
        if (type != 'mouseMoved') ...{'button': 'left', 'clickCount': 1},
      });
    }
  }
}
