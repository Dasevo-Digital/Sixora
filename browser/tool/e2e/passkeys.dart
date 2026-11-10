// The passkey path through a real browser: page, background, window and
// back, checked the way a website would check it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'common.dart';

/// A [Driver] that can also reach the window of a passkey request.
abstract interface class PasskeyDriver implements Driver {
  /// Waits for the window and acts on it from now on.
  Future<void> toPasskeyWindow();
  Future<void> toPage();
  Future<void> closePasskeyWindow();
  Future<bool> get passkeyWindowOpen;

  /// A click by the input system, which the page cannot fake.
  Future<void> trustedClick(String css);
}

/// A website that uses passkeys and verifies what comes back with
/// WebCrypto. Each result ends up as JSON in `#out`.
const passkeyTestPage = r'''<!doctype html><title>rp</title>
<p style="margin-top:80px"><input id="field" autocomplete="username webauthn"></p>
<pre id="out"></pre><script>
const b64 = (v) => btoa(String.fromCharCode(...new Uint8Array(v)))
  .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const from64 = (s) => Uint8Array.from(
  atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));
const bytes = (s) => new TextEncoder().encode(s);
const sha = (v) => crypto.subtle.digest("SHA-256", v);
const same = (a, b) => b64(a) === b64(b);
const out = (v) => { document.getElementById("out").textContent = JSON.stringify(v); };

function raw(der) {
  let at = 2;
  const part = () => {
    const length = der[at + 1];
    const value = der.slice(at + 2, at + 2 + length);
    at += 2 + length;
    const trimmed = value[0] === 0 ? value.slice(1) : value;
    const fixed = new Uint8Array(32);
    fixed.set(trimmed, 32 - trimmed.length);
    return fixed;
  };
  const r = part();
  const s = part();
  const all = new Uint8Array(64);
  all.set(r);
  all.set(s, 32);
  return all;
}

function clientFine(c, type, challenge) {
  const d = JSON.parse(new TextDecoder().decode(c.response.clientDataJSON));
  return d.type === type && d.origin === location.origin && d.challenge === b64(challenge);
}

async function created(c, challenge, rpId) {
  const spki = c.response.getPublicKey();
  const key = await crypto.subtle.importKey(
    "spki", spki, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
  localStorage.setItem("spki", b64(spki));
  localStorage.setItem("id", c.id);
  const auth = new Uint8Array(c.response.getAuthenticatorData());
  return {
    fine: Boolean(key) && c instanceof PublicKeyCredential && c.type === "public-key"
      && b64(c.rawId) === c.id
      && c.response instanceof AuthenticatorAttestationResponse
      && c.response.getPublicKeyAlgorithm() === -7
      && c.response.getTransports().includes("internal")
      && clientFine(c, "webauthn.create", challenge)
      && same(auth.slice(0, 32), await sha(bytes(rpId)))
      && typeof JSON.parse(JSON.stringify(c)).response.attestationObject === "string",
    flags: auth[32],
  };
}

async function signedIn(c, challenge) {
  const key = await crypto.subtle.importKey(
    "spki", from64(localStorage.getItem("spki")),
    { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
  const auth = new Uint8Array(c.response.authenticatorData);
  const hash = new Uint8Array(await sha(c.response.clientDataJSON));
  const signed = new Uint8Array(auth.length + hash.length);
  signed.set(auth);
  signed.set(hash, auth.length);
  return {
    fine: c instanceof PublicKeyCredential
      && c.response instanceof AuthenticatorAssertionResponse
      && c.id === localStorage.getItem("id")
      && b64(c.response.userHandle) === b64(bytes("user-1"))
      && clientFine(c, "webauthn.get", challenge)
      && await crypto.subtle.verify(
        { name: "ECDSA", hash: "SHA-256" }, key, raw(new Uint8Array(c.response.signature)), signed),
    flags: auth[32],
  };
}

// A password manager that hooks in after Sixora, then the user's click.
window.managerCalls = 0;
function addManager(capture) {
  const captured = capture !== "sixora"
    ? CredentialsContainer.prototype.create.bind(navigator.credentials)
    : navigator.credentials.create.bind(navigator.credentials);
  const other = async function other(e) {
    window.managerCalls++;
    await null;
    return captured(e);
  };
  if (capture === "pinned") {
    Object.defineProperty(navigator.credentials, "create", { value: other, writable: false, configurable: false });
  } else {
    navigator.credentials.create = other;
  }
  window.dispatchEvent(new Event("pointerdown"));
}

// The same for sign-ins, with Sixora's function captured: the worst case.
window.managerAborted = 0;
function addSignInManager() {
  const captured = navigator.credentials.get.bind(navigator.credentials);
  navigator.credentials.get = async function other(e) {
    window.managerCalls++;
    e.signal?.addEventListener("abort", () => window.managerAborted++);
    await null;
    return captured(e);
  };
  window.dispatchEvent(new Event("pointerdown"));
}

let controller = null;
let lastChallenge = null;
window.rp = (kind, text) => {
  if (kind === "abort") { controller.abort(); return; }
  if (kind === "manager") { addManager(JSON.parse(text).capture); return; }
  if (kind === "signInManager") { addSignInManager(); return; }
  document.getElementById("out").textContent = "";
  const spec = JSON.parse(text);
  const challenge = spec.sameChallenge
    ? lastChallenge : crypto.getRandomValues(new Uint8Array(32));
  lastChallenge = challenge;
  controller = new AbortController();
  if (spec.abortAfter) setTimeout(() => controller.abort(), spec.abortAfter);
  const signal = controller.signal;
  const mediation = spec.conditional ? { mediation: "conditional" } : {};
  const call = kind === "create"
    ? navigator.credentials.create({ signal, ...mediation, publicKey: {
        rp: { name: "Test RP", ...(spec.rpId ? { id: spec.rpId } : {}) },
        user: { id: bytes("user-1"), name: "alice@rp.example", displayName: "Alice" },
        challenge,
        pubKeyCredParams: [{ type: "public-key", alg: -7 }],
        excludeCredentials: spec.exclude
          ? [{ type: "public-key", id: from64(localStorage.getItem("id")) }] : [],
        authenticatorSelection: { userVerification: spec.uv ?? "discouraged" },
      } })
    : navigator.credentials.get({ signal, ...mediation, publicKey: {
        challenge,
        ...(spec.rpId ? { rpId: spec.rpId } : {}),
        allowCredentials: spec.allow === "mine"
          ? [{ type: "public-key", id: from64(localStorage.getItem("id")).buffer }]
          : spec.allow === "other"
          ? [{ type: "public-key", id: bytes("not in this vault") }] : [],
        userVerification: spec.uv ?? "discouraged",
      } });
  call.then(
    async (c) => out(await (kind === "create"
      ? created(c, challenge, spec.rpId ?? location.hostname)
      : signedIn(c, challenge))),
    (e) => out({ error: e.name }),
  );
};
</script>''';

const _flagUserVerified = 0x04;
const _flagsSynced = 0x01 | 0x08 | 0x10; // present, backup eligible, backed up

/// A page on [url] that uses the passkeys of the site [rpId], which names
/// it in its `/.well-known/webauthn`; [unlisted] does not.
class RelatedSite {
  const RelatedSite(this.url, this.rpId, this.unlisted);
  final String url;
  final String rpId;
  final String unlisted;
}

/// [hasApp]: the desktop app answers verification (Touch ID), so no
/// password is typed. [realSwitchOff]: the permission can really be taken
/// back; where the test granted it in the manifest, it cannot.
Future<int> runPasskeyScenario(
  PasskeyDriver d,
  String base, {
  required bool hasApp,
  required bool realSwitchOff,
  required String serverOrigin,
  RelatedSite? related,
}) async {
  var failures = 0;
  void check(String what, bool ok) {
    stdout.writeln('${ok ? 'ok  ' : 'FEHL'} $what');
    if (!ok) failures++;
  }

  final site = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  site.listen((request) {
    request.response
      ..headers.contentType = ContentType.html
      ..write(passkeyTestPage)
      ..close();
  });
  final rpUrl = 'http://localhost:${site.port}/';

  Future<void> ask(String kind, Map<String, Object?> spec) => d.script(
    'const w = window.wrappedJSObject ?? window; w.rp(arguments[0], arguments[1]);',
    [kind, jsonEncode(spec)],
  );

  Future<Map<String, Object?>> result() async {
    await d.waitFor('#out:not(:empty)', timeout: const Duration(seconds: 20));
    final text =
        await d.script("return document.getElementById('out').textContent;")
            as String;
    return (jsonDecode(text) as Map).cast();
  }

  Future<bool> stayedWithoutWindow() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return !await d.passkeyWindowOpen;
  }

  const suggestion = '[data-sixora-passkey]';

  Future<void> focusField() =>
      d.script("document.getElementById('field').focus();");

  Future<bool> suggested() async =>
      await d.script('return !!document.querySelector(arguments[0]);', [
        suggestion,
      ]) ==
      true;

  Future<bool> stayedWithoutSuggestion() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return !await suggested();
  }

  Future<String> outputNow() async =>
      await d.script("return document.getElementById('out').textContent;")
          as String;

  // Switched on in the settings.
  await d.navigate('$base/popup.html');
  await d.waitFor('.row, input[type=password]');
  if (await d.script("return !document.querySelector('.row');") == true) {
    await d.type('input[type=password]', password);
    await d.click('button[type=submit]');
    await d.waitFor('.row', timeout: const Duration(seconds: 30));
  }
  await d.click('header .actions button.icon:last-child');
  await d.waitFor('.passkey-switch');
  await d.click('.passkey-switch');
  await d.waitFor('.passkey-switch');
  final end = DateTime.now().add(const Duration(seconds: 10));
  Object? scripts;
  while (DateTime.now().isBefore(end)) {
    scripts = await d.script(
      'const w = window.wrappedJSObject ?? window;'
      'const s = await (w.browser ?? w.chrome).scripting'
      '.getRegisteredContentScripts();'
      'return s.map(x => x.id).sort().join();',
    );
    if ((scripts as String).isNotEmpty) break;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  check(
    'switched on ($scripts)',
    scripts == 'sixora-passkey-page,sixora-passkey-relay',
  );

  // Making one.
  await d.navigate(rpUrl);
  await ask('create', {});
  await d.toPasskeyWindow();
  await d.waitFor('.passkey-site', timeout: const Duration(seconds: 30));
  final shown = await d.script(
    "return document.querySelector('.passkey-site').textContent;",
  );
  check('window names the site the browser vouches for', shown == 'localhost');
  await d.click('main button.primary');
  await d.toPage();
  var r = await result();
  check('new passkey accepted by the page $r', r['fine'] == true);
  check(
    'flags say synced, not verified',
    (r['flags']! as int) & (_flagsSynced | _flagUserVerified) == _flagsSynced,
  );

  // Already registered with this site.
  await ask('create', {'exclude': true});
  await d.toPasskeyWindow();
  await d.waitFor('main button.primary', timeout: const Duration(seconds: 30));
  await d.click('main button.primary');
  await d.toPage();
  r = await result();
  check('exclude list $r', r['error'] == 'InvalidStateError');

  // Signing in.
  await ask('get', {});
  await d.toPasskeyWindow();
  await d.waitFor('.passkey-list .row', timeout: const Duration(seconds: 30));
  await d.click('.passkey-list .row');
  await d.toPage();
  r = await result();
  check('signature verifies with WebCrypto $r', r['fine'] == true);
  check(
    'no verification claimed without one',
    (r['flags']! as int) & _flagUserVerified == 0,
  );

  // A site that requires verification.
  await ask('get', {'uv': 'required'});
  await d.toPasskeyWindow();
  await d.waitFor('.passkey-list .row', timeout: const Duration(seconds: 30));
  await d.click('.passkey-list .row');
  if (!hasApp) {
    await d.waitFor('input[type=password]');
    await d.type('input[type=password]', password);
    await d.click('button[type=submit]');
  }
  await d.toPage();
  r = await result();
  check(
    'verification required $r',
    r['fine'] == true && (r['flags']! as int) & _flagUserVerified != 0,
  );

  // The site names the passkeys of the account signing in.
  await ask('get', {'allow': 'mine'});
  await d.toPasskeyWindow();
  await d.waitFor('.passkey-list .row', timeout: const Duration(seconds: 30));
  await d.click('.passkey-list .row');
  await d.toPage();
  r = await result();
  check('allow list naming this passkey $r', r['fine'] == true);

  // None of them is here: after asking the server, the window says which
  // account Sixora does have, instead of vanishing.
  await ask('get', {'allow': 'other'});
  await d.toPasskeyWindow();
  await d.waitFor(
    'main button.secondary',
    timeout: const Duration(seconds: 30),
  );
  final told = await d.script(
    "return document.querySelector('main').textContent;",
  );
  check(
    'names the account it has ($told)',
    (told as String).contains('alice@rp.example'),
  );
  await d.click('main button.secondary');
  await d.toPage();
  await ask('abort', {});
  r = await result();
  check('and hands the request on $r', !await d.passkeyWindowOpen);

  // The page withdraws its request.
  await ask('get', {});
  await d.toPasskeyWindow();
  await d.waitFor('.passkey-list .row', timeout: const Duration(seconds: 30));
  await d.toPage();
  await ask('abort', {});
  r = await result();
  await Future<void>.delayed(const Duration(milliseconds: 500));
  check(
    'abort closes the window $r',
    r['error'] == 'AbortError' && !await d.passkeyWindowOpen,
  );

  // Another site's domain: the browser refuses, no window.
  await ask('get', {'rpId': 'example.com'});
  r = await result();
  check(
    'foreign rpId left to the browser $r',
    r['error'] == 'SecurityError' && await stayedWithoutWindow(),
  );

  if (related != null) {
    await d.navigate(related.url);
    await ask('create', {'rpId': related.rpId});
    await d.toPasskeyWindow();
    await d.waitFor('.passkey-site', timeout: const Duration(seconds: 30));
    final named = await d.script(
      "return document.querySelector('.passkey-site').textContent;",
    );
    check(
      'related origin named with its site ($named)',
      named == '${Uri.parse(related.url).host} (${related.rpId})',
    );
    await d.click('main button.primary');
    await d.toPage();
    r = await result();
    check('passkey made on a related origin $r', r['fine'] == true);

    await ask('get', {'rpId': related.rpId});
    await d.toPasskeyWindow();
    await d.waitFor('.passkey-list .row', timeout: const Duration(seconds: 30));
    await d.click('.passkey-list .row');
    await d.toPage();
    r = await result();
    check('sign-in on a related origin $r', r['fine'] == true);

    await ask('get', {'rpId': related.unlisted, 'abortAfter': 1500});
    check('a site that does not name it', await stayedWithoutWindow());
    await result();

    // In the field: the shared passkey, nothing of a site that does not
    // name this address, nothing where no passkey is stored.
    await focusField();
    await ask('get', {'conditional': true, 'rpId': related.rpId});
    await d.waitFor(suggestion);
    check('suggestion on a related origin', await suggested());
    await ask('abort', {});
    await result();
    await ask('get', {
      'conditional': true,
      'rpId': related.unlisted,
      'abortAfter': 1500,
    });
    check(
      'no suggestion for a site that does not name it',
      await stayedWithoutSuggestion(),
    );
    await result();
    await d.navigate('https://${related.unlisted}/');
    await focusField();
    await ask('get', {'conditional': true, 'abortAfter': 1500});
    check(
      'no suggestion where no passkey is stored',
      await stayedWithoutSuggestion(),
    );
    await result();
    await d.navigate(rpUrl);
  }

  // Signing in from the suggestion in the field.
  await d.navigate(rpUrl);
  await ask('get', {'conditional': true});
  check('nothing shown before the field has the focus', !await suggested());
  await focusField();
  await d.waitFor(suggestion);
  check('suggestion at the field, no window yet', !await d.passkeyWindowOpen);
  await d.trustedClick(suggestion);
  await d.toPasskeyWindow();
  await d.waitFor('.passkey-list .row', timeout: const Duration(seconds: 30));
  await d.click('.passkey-list .row');
  await d.toPage();
  r = await result();
  check('sign-in from the suggestion $r', r['fine'] == true);
  check('suggestion gone afterwards', !await suggested());

  // Closing the window withdraws nothing: the page's request stays open
  // and the suggestion comes back; it also works right after that "no".
  await ask('get', {'conditional': true});
  await d.waitFor(suggestion);
  await d.trustedClick(suggestion);
  await d.toPasskeyWindow();
  await d.waitFor('.passkey-list .row', timeout: const Duration(seconds: 30));
  await d.closePasskeyWindow();
  await d.toPage();
  await d.waitFor(suggestion);
  check('a no leaves the request open', await outputNow() == '');
  await d.trustedClick(suggestion);
  await d.toPasskeyWindow();
  await d.waitFor('.passkey-list .row', timeout: const Duration(seconds: 30));
  await d.click('.passkey-list .row');
  await d.toPage();
  r = await result();
  check('suggestion works right after a no $r', r['fine'] == true);

  // The page withdraws; a real sign-in may reuse the challenge.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await ask('get', {'conditional': true});
  await d.waitFor(suggestion);
  await ask('abort', {});
  r = await result();
  check('page withdraws the suggestion $r', r['error'] == 'AbortError');
  check('suggestion gone with it', !await suggested());
  // A "no" above paused modal requests of this tab.
  await Future<void>.delayed(const Duration(seconds: 10));
  await ask('get', {'sameChallenge': true});
  await d.toPasskeyWindow();
  await d.waitFor('.passkey-list .row', timeout: const Duration(seconds: 30));
  check('same challenge reaches Sixora as a real sign-in', true);
  await d.click('.passkey-list .row');
  await d.toPage();
  r = await result();
  check('and signs in $r', r['fine'] == true);

  // Beside another manager: it gets the request too and is withdrawn.
  await d.navigate(rpUrl);
  await ask('signInManager', {});
  await ask('get', {'conditional': true});
  await focusField();
  await d.waitFor(suggestion);
  final seen = await d.script(
    'return (window.wrappedJSObject ?? window).managerCalls;',
  );
  check('the other manager sees the request ($seen)', seen == 1);
  await d.trustedClick(suggestion);
  await d.toPasskeyWindow();
  await d.waitFor('.passkey-list .row', timeout: const Duration(seconds: 30));
  await d.click('.passkey-list .row');
  await d.toPage();
  r = await result();
  check('Sixora answers beside it $r', r['fine'] == true);
  final withdrawn = await d.script(
    'return (window.wrappedJSObject ?? window).managerAborted;',
  );
  check('the other manager is withdrawn ($withdrawn)', withdrawn == 1);

  // No suggestion for another site's passkeys, no silent creation.
  await d.navigate(rpUrl);
  await focusField();
  await ask('get', {'conditional': true, 'rpId': 'example.com'});
  r = await result();
  check(
    'foreign rpId: no suggestion, the browser reports it $r',
    r['error'] == 'SecurityError' && !await suggested(),
  );
  await ask('create', {'conditional': true, 'abortAfter': 1000});
  check('nothing made silently', await stayedWithoutWindow());
  await result();

  // Another password manager that hooks in later, whether it captured the
  // browser's function or Sixora's own, or pinned its function in place.
  for (final capture in ['browser', 'sixora', 'pinned']) {
    await d.navigate(rpUrl);
    await ask('manager', {'capture': capture});
    await ask('create', {});
    await d.toPasskeyWindow();
    await d.waitFor(
      'main button.secondary',
      timeout: const Duration(seconds: 30),
    );
    await d.click('main button.secondary');
    await d.toPage();
    Object? calls;
    final until = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(until)) {
      calls = await d.script(
        'return (window.wrappedJSObject ?? window).managerCalls;',
      );
      if (calls == 1) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    check('Sixora first, then the other manager ($capture)', calls == 1);
    await ask('abort', {});
    r = await result();
    check(
      'and on to the browser, no loop ($capture) $r',
      !await d.passkeyWindowOpen,
    );
  }
  await d.navigate(rpUrl);

  // Closing the window means no; and the page cannot reopen it at once.
  await ask('get', {});
  await d.toPasskeyWindow();
  await d.waitFor('.passkey-list .row', timeout: const Duration(seconds: 30));
  await d.closePasskeyWindow();
  await d.toPage();
  r = await result();
  check('closing the window $r', r['error'] == 'NotAllowedError');
  await ask('get', {'abortAfter': 1000});
  check('no new window right after a no', await stayedWithoutWindow());
  await result();

  // The codes stay as they are; the passkey is not an unreadable code.
  await d.navigate('$base/popup.html');
  await d.waitFor('.row', timeout: const Duration(seconds: 20));
  final codes = await d.script(
    "return [document.querySelectorAll('.row').length,"
    "document.querySelector('.status.visible')?.textContent ?? ''];",
  );
  check('popup unchanged $codes', jsonEncode(codes) == '[2,""]');

  // Switched off: pages are left alone again.
  if (realSwitchOff) {
    await d.click('header .actions button.icon:last-child');
    await d.waitFor('.passkey-switch');
    await d.click('.passkey-switch');
    await Future<void>.delayed(const Duration(seconds: 1));
    final kept = await d.script(
      'const w = window.wrappedJSObject ?? window;'
      'return (w.browser ?? w.chrome).permissions.contains('
      '{origins: [arguments[0]]});',
      [serverOrigin],
    );
    check('switching off keeps the server permission', kept == true);
  } else {
    await d.script(
      'await chrome.storage.local.remove("passkeysWanted");'
      'return chrome.runtime.sendMessage({sixora: "passkey-scripts"});',
    );
  }
  await d.navigate(rpUrl);
  final untouched = await d.script(
    'const w = window.wrappedJSObject ?? window;'
    'return String(w.navigator.credentials.get).includes("native code");',
  );
  check('switched off, the page has the browser again', untouched == true);

  await site.close(force: true);
  return failures;
}
