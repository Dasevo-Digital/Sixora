import 'dart:convert';
import 'dart:typed_data';

import 'package:sixora_core/sixora_core.dart';

import 'extension.dart';

/// Sends a request to the Sixora desktop app and returns its answer;
/// `{"error": ...}` when there is no app. [keep] names the session entry
/// that keeps the answer if the popup closes before it arrives.
typedef AskApp =
    Future<Map<String, Object?>> Function(
      Map<String, Object?> request, {
      required Duration timeout,
      String? keep,
    });

/// What the desktop app answers about itself.
class AppStatus {
  const AppStatus({
    required this.method,
    required this.paired,
    required this.ready,
    this.appUnlocked,
  });

  /// "Touch ID", "Windows Hello", or "" for a dialog in the app.
  final String method;

  /// Whether the user connected this extension in the app.
  final bool paired;

  /// Whether a request reaches the user now (the app is unlocked, or this
  /// extension is connected and the app has quick unlock).
  final bool ready;

  /// Whether the app itself is unlocked; only told to a connected
  /// extension, and null with an app that does not tell yet.
  final bool? appUnlocked;
}

/// "Mit Touch ID entsperren": the extension asks the desktop app (see
/// [BrowserLink]), which confirms with Touch ID, Windows Hello or a dialog
/// and sends the user key sealed to this extension's own key.
///
/// The key pair is made on first use and stays in `storage.local`: the app
/// connects it once (both show the same code) and from then on hands out
/// the user key only sealed to it. An answer that arrives after the popup
/// closed (Touch ID takes the focus) waits in `storage.session` for the
/// next popup ([resume]).
class AppUnlock {
  AppUnlock(this.x, this.ask, {required this.browser});

  final SixoraExtension x;
  final AskApp ask;

  /// Shown in the app, e.g. "Opera".
  final String browser;

  /// A request is out (`storage.session`).
  static const _pending = 'appUnlock';
  static const _reply = 'appUnlockReply';

  /// Not asked again on its own after the user declined, until the next
  /// unlock.
  static const _declined = 'appUnlockDeclined';

  Future<({String publicKey, Uint8List privateKey})> _key() async {
    final text = await x.local.read(SixoraExtension.linkKeyEntry);
    if (text != null) {
      try {
        final j = (jsonDecode(text) as Map).cast<String, Object?>();
        return (
          publicKey: j['publicKey']! as String,
          privateKey: base64.decode(j['privateKey']! as String),
        );
      } on Object {
        // Damaged: a new one, to be connected again.
      }
    }
    final keys = await VaultCrypto.newKeyPair();
    await x.local.write(
      SixoraExtension.linkKeyEntry,
      jsonEncode({
        'publicKey': keys.publicKey,
        'privateKey': base64.encode(keys.privateKey),
      }),
    );
    return keys;
  }

  Map<String, Object?> _request(String type, String publicKey) {
    final s = x.stored!;
    return {
      'type': type,
      'account': BrowserLink.accountTag(s.server, s.account.id),
      'publicKey': publicKey,
      if (type == 'unlock') 'browser': browser,
    };
  }

  /// The Sixora app on this computer, if it uses this account; null
  /// without one.
  Future<AppStatus?> status({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (x.stored == null) return null;
    final key = await _key();
    final hello = await ask(_request('hello', key.publicKey), timeout: timeout);
    if (hello['sixora'] != BrowserLink.protocol ||
        hello['sameAccount'] != true) {
      return null;
    }
    return AppStatus(
      method: hello['method'] as String? ?? '',
      paired: hello['paired'] == true,
      ready: hello['ready'] == true,
      appUnlocked: hello['unlocked'] as bool?,
    );
  }

  /// At every opening a connected extension follows the app: open without
  /// asking while the app is unlocked, locked when it is locked. Without
  /// the app, or locked by hand, the extension stays as it is.
  Future<void> followApp() async {
    const wait = Duration(seconds: 2);
    try {
      if (x.stored == null) return;
      final app = await status(timeout: wait);
      if (app == null || !app.paired) return;
      if (app.appUnlocked == false) {
        if (x.stage == Stage.unlocked) await x.lock();
        return;
      }
      if (app.appUnlocked != true) return;
      final opens = x.stage == Stage.locked && !await x.lockedByUser;
      // Also asks once while open: the app's key is in the same answer.
      if (!opens && await x.local.read(SixoraExtension.appKeyEntry) != null) {
        return;
      }
      final key = await _key();
      final reply = await ask(
        _request('session', key.publicKey),
        timeout: wait,
      );
      final sealed = reply['sealedUserKey'];
      if (sealed is! String) return;
      final userKey = await VaultCrypto.unseal(
        sealed,
        key.privateKey,
        key.publicKey,
      );
      if (opens) await x.unlockWithUserKey(userKey);
      await _rememberAppKey(reply, userKey);
      if (!opens) userKey.fillRange(0, userKey.length, 0);
    } on Object {
      // The lock screen offers the other ways.
    }
  }

  /// Keeps the app's key if the answer proves it, which takes the real user
  /// key: a program posing as the app has neither.
  Future<void> _rememberAppKey(
    Map<String, Object?> reply,
    Uint8List userKey,
  ) async {
    final appKey = reply['appKey'];
    if (appKey is! String ||
        reply['appKeyProof'] != BrowserLink.appKeyProof(userKey, appKey) ||
        !await x.opensAccount(userKey)) {
      return;
    }
    await x.local.write(SixoraExtension.appKeyEntry, appKey);
  }

  /// After the master password: a locked app on this computer opens too.
  /// Without a proven key of the app the user key stays here.
  Future<void> openApp() async {
    try {
      final appKey = await x.local.read(SixoraExtension.appKeyEntry);
      if (appKey == null) return;
      final app = await status(timeout: const Duration(seconds: 2));
      if (app == null || !app.paired || app.appUnlocked != false) return;
      final sealed = await x.sealUserKey(appKey);
      if (sealed == null) return;
      final key = await _key();
      await ask({
        ..._request('openApp', key.publicKey),
        'sealedUserKey': sealed,
      }, timeout: const Duration(seconds: 5));
    } on Object {
      // The app stays as it is.
    }
  }

  /// The code the app shows when it connects this extension.
  Future<String> code() async => BrowserLink.code((await _key()).publicKey);

  /// Whether to ask right away when the popup opens.
  Future<bool> get declined async => await x.session.read(_declined) != null;

  /// Asks the app: connects this extension the first time, afterwards
  /// unlocks with Touch ID & co.
  Future<void> unlock() async {
    final key = await _key();
    await x.session.write(_reply, null);
    await x.session.write(_pending, '1');
    final reply = await ask(
      _request('unlock', key.publicKey),
      timeout: BrowserLink.confirmTimeout + const Duration(seconds: 10),
      keep: _reply,
    );
    await _finish(reply);
  }

  /// An answer that arrived while no popup was open. True if it unlocked.
  Future<bool> resume() async {
    final text = await x.session.read(_reply);
    if (text == null || await x.session.read(_pending) == null) return false;
    try {
      await _finish((jsonDecode(text) as Map).cast());
      return true;
    } on Object {
      return false;
    }
  }

  /// Forgets a waiting request: a late answer then opens nothing.
  Future<void> cancel() async {
    await x.session.write(_pending, null);
    await x.session.write(_reply, null);
  }

  Future<void> _finish(Map<String, Object?> reply) async {
    final pending = await x.session.read(_pending);
    await cancel();
    if (pending == null) throw const ExtensionError('app_cancelled');
    final sealed = reply['sealedUserKey'];
    if (sealed is! String) {
      final error = reply['error'] as String? ?? 'failed';
      if (error == 'denied') await x.session.write(_declined, '1');
      throw ExtensionError(switch (error) {
        'not_running' || 'no_host' => 'app_not_running',
        'denied' ||
        'locked' ||
        'other_account' ||
        'busy' ||
        'timeout' => 'app_$error',
        _ => 'app_failed',
      });
    }
    final key = await _key();
    try {
      final userKey = await VaultCrypto.unseal(
        sealed,
        key.privateKey,
        key.publicKey,
      );
      await x.unlockWithUserKey(userKey);
      await _rememberAppKey(reply, userKey);
    } on CryptoException {
      throw const ExtensionError('app_failed');
    }
    await x.session.write(_declined, null);
  }
}
