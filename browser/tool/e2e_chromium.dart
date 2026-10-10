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

import 'package:crypto/crypto.dart';

import 'e2e/common.dart';

Future<void> main() async {
  final app =
      Platform.environment['CHROMIUM_APP'] ??
      '/Applications/Opera.app/Contents/MacOS/Opera';
  final work = Directory.systemTemp.createTempSync('sixora-e2e-');
  final server = await TestServer.start();
  Process? browser;
  var failures = 0;
  try {
    // A copy whose host permission for the test server is already granted:
    // headless, nobody could answer the browser's question.
    final extension = Directory('${work.path}/extension');
    await Process.run('cp', ['-R', 'build/chromium', extension.path]);
    final manifest = File('${extension.path}/manifest.json');
    final json = (jsonDecode(manifest.readAsStringSync()) as Map)
      ..['host_permissions'] = ['http://127.0.0.1/*'];
    manifest.writeAsStringSync(jsonEncode(json));
    final path = extension.resolveSymbolicLinksSync();
    final port = 29300 + DateTime.now().millisecond % 500;
    browser = await Process.start(app, [
      '--headless=new',
      '--remote-debugging-port=$port',
      '--user-data-dir=${work.path}/profile',
      '--load-extension=$path',
      '--disable-features=DisableLoadExtensionCommandLineSwitch,LocalNetworkAccessChecks',
      '--no-first-run',
      '--no-default-browser-check',
      'about:blank',
    ]);
    final cdp = await Cdp.connect(port);
    failures = await runScenario(
      cdp,
      'chrome-extension://${_unpackedId(path)}',
      server.url,
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
    await server.stop();
    work.deleteSync(recursive: true);
  }
  if (failures > 0) {
    stderr.writeln('$failures Prüfungen fehlgeschlagen');
    exit(1);
  }
  stdout.writeln('Alle Prüfungen bestanden.');
}

/// Chromium names an unpacked extension after its folder: SHA-256 of the
/// path, the first 32 hex digits written with the letters a–p.
String _unpackedId(String path) => sha256
    .convert(utf8.encode(path))
    .toString()
    .substring(0, 32)
    .split('')
    .map((h) => String.fromCharCode(97 + int.parse(h, radix: 16)))
    .join();

/// A minimal DevTools protocol client for one tab.
class Cdp implements Driver {
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
}
