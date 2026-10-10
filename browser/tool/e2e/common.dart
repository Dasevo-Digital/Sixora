// What the end-to-end tests of Firefox and Chromium share: a Sixora server
// in this process with one account, and the same checks for both browsers.
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as io;
import 'package:sixora_core/sixora_core.dart';
import 'package:sixora_server/sixora_server.dart';

const password = 'master-passwort-123';
const secret = 'JBSWY3DPEHPK3PXP';

/// Remote control of a browser tab.
abstract interface class Driver {
  Future<void> navigate(String url);

  /// Runs [body] as a function in the page (`arguments`, `return`, may
  /// return a promise) and returns its JSON value.
  Future<Object?> script(String body, [List<Object?> args = const []]);
  Future<void> type(String css, String text);

  /// A real click (user gesture).
  Future<void> click(String css);
}

extension Waiting on Driver {
  Future<void> waitFor(
    String css, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      final found = await script(
        'return !!document.querySelector(arguments[0]);',
        [css],
      );
      if (found == true) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final text = await script('return document.body.innerText;');
    throw StateError('$css nicht gefunden. Seite: $text');
  }
}

class TestServer {
  TestServer._(this._app, this._server);
  final SixoraServerApp _app;
  final HttpServer _server;

  String get url => 'http://127.0.0.1:${_server.port}/';

  /// With an account "alice": GitHub and a Steam code.
  static Future<TestServer> start() async {
    final app = SixoraServerApp(
      db: openSixoraDatabase(':memory:'),
      registration: Registration.open,
    );
    final server = await io.serve(app.handler, InternetAddress.loopbackIPv4, 0);
    final s = TestServer._(app, server);
    await s._seed();
    return s;
  }

  Future<void> _seed() async {
    const kdf = KdfParams(memoryKiB: 19456, iterations: 2);
    final created = await NewAccount.create(
      username: 'alice',
      password: password,
      kdf: kdf,
    );
    final api = SixoraApi(Uri.parse(url));
    final r = await api.register({
      ...created.body,
      'device': const DeviceInfo(name: 'Mac', platform: 'macos').toJson(),
    });
    final keys = await UnlockedKeys.unlock(r.account, created.kek);
    final vault = (await api.sync(0)).vaults.single;
    final key = await keys.openVaultKey(vault);
    for (final entry in const [
      OtpEntry(issuer: 'GitHub', account: 'alice', secret: secret),
      OtpEntry(
        issuer: 'Steam',
        account: 'alice',
        secret: 'GEZDGNBVGY3TQOJQ',
        type: OtpType.steam,
      ),
    ]) {
      final id = VaultCrypto.newId();
      await api.putEntry(
        id: id,
        vaultId: vault.id,
        data: await UnlockedKeys.encryptEntry(key, vault.id, id, entry),
        baseRevision: 0,
      );
    }
    api.close();
  }

  Future<void> stop() async {
    await _server.close(force: true);
    _app.db.close();
  }
}

/// The checks, the same in every browser. [base] is the extension's own
/// address (moz-extension://… or chrome-extension://…). Returns the
/// number of failed checks.
Future<int> runScenario(Driver d, String base, String serverUrl) async {
  var failures = 0;
  void check(String what, bool ok) {
    stdout.writeln('${ok ? 'ok  ' : 'FEHL'} $what');
    if (!ok) failures++;
  }

  // First sign-in, in the setup tab.
  await d.navigate('$base/popup.html#setup');
  await d.waitFor('form input[autocomplete=url]');
  await d.type('input[autocomplete=url]', serverUrl);
  await d.type('input[autocomplete=username]', 'alice');
  await d.type('input[type=password]', password);
  await d.click('button[type=submit]');
  await d.waitFor('.done', timeout: const Duration(seconds: 30));
  check('sign-in', true);

  // The popup: codes as in the apps.
  await d.navigate('$base/popup.html');
  await d.waitFor('.row');
  final shown =
      (await d.script(
            "return [...document.querySelectorAll('.row')].map(r => "
            "r.querySelector('.issuer').textContent + '=' + "
            "r.querySelector('.code').textContent.replace(' ', ''))",
          ))!
          as List;
  final now = DateTime.now();
  final expected = {
    for (final t in [now, now.subtract(const Duration(seconds: 2))])
      'GitHub=${Otp.generate(secret: secret, type: OtpType.totp, time: t)}',
  };
  check(
    'codes shown ($shown)',
    shown.length == 2 && expected.contains(shown.first),
  );

  // The profile holds ciphertext only.
  final stored = jsonEncode(
    await d.script(
      'const w = window.wrappedJSObject ?? window;'
      'return (w.browser ?? w.chrome).storage.local.get();',
    ),
  );
  check(
    'storage holds no secrets',
    stored.contains('account') &&
        !stored.contains(secret) &&
        !stored.contains('GitHub'),
  );

  // Locking and unlocking.
  await d.click('button[title]');
  await d.waitFor('input[type=password]');
  await d.type('input[type=password]', password);
  await d.click('button[type=submit]');
  await d.waitFor('.row');
  check('lock and unlock', true);

  // The function that fills web pages.
  final source = File('static/bridge.js').readAsStringSync();
  final start = source.indexOf('function fillInPage(code) {');
  final fill = source.substring(start, source.indexOf('\n}\n', start) + 2);
  Future<String> fillPage(String html, String code) async {
    await d.navigate('about:blank');
    return jsonEncode(
      await d.script(
        'document.body.innerHTML = arguments[0];'
        'window.events = 0;'
        "document.addEventListener('input', () => window.events++);"
        '$fill\n'
        'const filled = fillInPage(arguments[1]);'
        "return [filled, [...document.querySelectorAll('input')].map(i => i.value), window.events];",
        [html, code],
      ),
    );
  }

  var r = await fillPage(
    '<input name="email" autocomplete="username">'
        '<input autocomplete="one-time-code">',
    '123456',
  );
  check('autocomplete=one-time-code $r', r == '[true,["","123456"],1]');
  r = await fillPage(
    '<input name="user"><label for="c">Authentication code</label><input id="c">',
    '123456',
  );
  check('label "Authentication code" $r', r == '[true,["","123456"],1]');
  r = await fillPage(
    List.filled(6, '<input maxlength="1" inputmode="numeric">').join(),
    '654321',
  );
  check('one box per digit $r', r == '[true,["6","5","4","3","2","1"],6]');
  r = await fillPage('<input name="promo_code">', '123456');
  check('promo code left alone $r', r == '[false,[""],0]');
  r = await fillPage(
    '<input name="otp" type="hidden"><input name="q" type="search">',
    '123456',
  );
  check('hidden and search fields left alone $r', r == '[false,["",""],0]');
  return failures;
}
