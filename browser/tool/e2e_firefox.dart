// End-to-end test of the extension in a real Firefox, headless and with a
// throwaway profile (the user's Firefox stays untouched):
//
//   tool/build.sh && dart run tool/e2e_firefox.dart
//
// Firefox loads build/firefox as a temporary add-on and is driven over
// Marionette; the checks are in e2e/common.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'e2e/common.dart';

const firefox = '/Applications/Firefox.app';
const addonId = '{8f8c1986-faf4-48a3-a267-a6c28c12f5ec}';
const addonHost = '6d1f2c4e-7a3b-4c59-9e8d-0b1a2c3d4e5f';

Future<void> main() async {
  final work = Directory.systemTemp.createTempSync('sixora-e2e-');
  final server = await TestServer.start();
  var started = false;
  var failures = 0;
  try {
    final profile = Directory('${work.path}/profile')..createSync();
    // A port of its own: another Firefox may still hold the default one.
    final port = 28300 + DateTime.now().millisecond % 500;
    File('${profile.path}/user.js').writeAsStringSync(
      [
        'user_pref("marionette.port", $port);',
        // Optional permissions (the server) are granted without a prompt.
        'user_pref("extensions.webextOptionalPermissionPrompts", false);',
        'user_pref("extensions.webextensions.uuids", ${jsonEncode(jsonEncode({addonId: addonHost}))});',
        // The test server runs on 127.0.0.1; a real one is a public address.
        'user_pref("network.lna.enabled", false);',
        'user_pref("network.lna.blocking", false);',
        'user_pref("browser.shell.checkDefaultBrowser", false);',
        'user_pref("datareporting.policy.dataSubmissionEnabled", false);',
        'user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);',
        'user_pref("browser.startup.homepage_override.mstone", "ignore");',
      ].join('\n'),
    );
    // Through `open`: macOS protects Firefox's own data folder from other
    // programs, and a Firefox started as a child of this one would inherit
    // that and find no profile at all.
    final open = await Process.run('open', [
      '-n',
      '-g',
      '-a',
      firefox,
      '--args',
      '--headless',
      '--marionette',
      // Extension pages can only be opened from the browser itself.
      '--remote-allow-system-access',
      '--no-remote',
      '--profile',
      profile.path,
    ]);
    if (open.exitCode != 0) throw StateError('open: ${open.stderr}');
    started = true;
    final m = await Marionette.connect(port);
    await m.cmd('WebDriver:NewSession', {'capabilities': {}});
    // A copy outside the project: macOS would ask whether Firefox may read
    // the Documents folder (and wait for an answer).
    final addon = '${work.path}/addon';
    await Process.run('cp', ['-R', 'build/firefox', addon]);
    await m.cmd('Addon:Install', {'path': addon, 'temporary': true});
    failures = await runScenario(m, 'moz-extension://$addonHost', server.url);
    await m.cmd('WebDriver:DeleteSession');
  } on Object catch (e) {
    stderr.writeln('FEHLER: $e');
    failures++;
  } finally {
    if (started) {
      await Process.run('pkill', ['-f', work.path]);
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    await server.stop();
    work.deleteSync(recursive: true);
  }
  if (failures > 0) {
    stderr.writeln('$failures Prüfungen fehlgeschlagen');
    exit(1);
  }
  stdout.writeln('Alle Prüfungen bestanden.');
}

/// A minimal client for Firefox's Marionette protocol (`length:json`).
class Marionette implements Driver {
  Marionette._(this._socket) {
    _socket.listen(_receive);
  }

  final Socket _socket;
  final _buffer = <int>[];
  final _pending = <int, Completer<Object?>>{};
  final _hello = Completer<Object?>();
  var _id = 0;

  static Future<Marionette> connect(int port) async {
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (true) {
      try {
        final m = Marionette._(await Socket.connect('127.0.0.1', port));
        await m._hello.future;
        return m;
      } on SocketException {
        if (DateTime.now().isAfter(end)) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  void _receive(List<int> data) {
    _buffer.addAll(data);
    while (true) {
      final colon = _buffer.indexOf(58);
      if (colon < 0) return;
      final length = int.parse(ascii.decode(_buffer.sublist(0, colon)));
      if (_buffer.length < colon + 1 + length) return;
      final message = jsonDecode(
        utf8.decode(_buffer.sublist(colon + 1, colon + 1 + length)),
      );
      _buffer.removeRange(0, colon + 1 + length);
      if (message is Map) {
        if (!_hello.isCompleted) _hello.complete(message);
        continue;
      }
      final [_, id as int, error, result] = message as List;
      final done = _pending.remove(id)!;
      if (error != null) {
        done.completeError(StateError(jsonEncode(error)));
      } else {
        done.complete(result);
      }
    }
  }

  Future<Object?> cmd(String name, [Map<String, Object?> params = const {}]) {
    if (Platform.environment['E2E_DEBUG'] != null) stderr.writeln('> $name');
    final id = ++_id;
    final done = _pending[id] = Completer<Object?>();
    final body = utf8.encode(jsonEncode([0, id, name, params]));
    _socket.add([...ascii.encode('${body.length}:'), ...body]);
    return done.future.timeout(const Duration(seconds: 30));
  }

  @override
  Future<void> navigate(String url) async {
    if (!url.startsWith('moz-extension:')) {
      await cmd('WebDriver:Navigate', {'url': url});
      return;
    }
    // WebDriver may not open extension pages; the browser window may.
    await cmd('Marionette:SetContext', {'value': 'chrome'});
    await cmd('WebDriver:ExecuteScript', {
      'script':
          'gBrowser.selectedBrowser.loadURI(Services.io.newURI(arguments[0]), '
          '{triggeringPrincipal: Services.scriptSecurityManager.getSystemPrincipal()});',
      'args': [url],
    });
    await cmd('Marionette:SetContext', {'value': 'content'});
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(end)) {
      final r = await cmd('WebDriver:GetCurrentURL');
      final current = (r! as Map)['value'] as String;
      final ready = await script('return document.readyState;');
      if (current == url && ready == 'complete') return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    throw StateError('$url lädt nicht');
  }

  @override
  Future<Object?> script(String body, [List<Object?> args = const []]) async {
    final r = await cmd('WebDriver:ExecuteScript', {
      'script': 'return (async () => { $body }).apply(null, arguments);',
      'args': args,
    });
    return (r! as Map)['value'];
  }

  Future<String> _find(String css) async {
    final r = await cmd('WebDriver:FindElement', {
      'using': 'css selector',
      'value': css,
    });
    return ((r! as Map)['value'] as Map).values.first as String;
  }

  @override
  Future<void> type(String css, String text) async =>
      cmd('WebDriver:ElementSendKeys', {'id': await _find(css), 'text': text});

  @override
  Future<void> click(String css) async =>
      cmd('WebDriver:ElementClick', {'id': await _find(css)});
}
