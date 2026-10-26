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
  });

  /// "Touch ID", "Windows Hello", or "" for a dialog in the app.
  final String method;

  /// Whether the user connected this extension in the app.
  final bool paired;

  /// Whether a request reaches the user now (the app is unlocked, or this
  /// extension is connected and the app has quick unlock).
  final bool ready;
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
  Future<AppStatus?> status() async {
    if (x.stored == null) return null;
    final key = await _key();
    final hello = await ask(
      _request('hello', key.publicKey),
      timeout: const Duration(seconds: 4),
    );
    if (hello['sixora'] != BrowserLink.protocol ||
        hello['sameAccount'] != true) {
      return null;
    }
    return AppStatus(
      method: hello['method'] as String? ?? '',
      paired: hello['paired'] == true,
      ready: hello['ready'] == true,
    );
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
      await x.unlockWithUserKey(
        await VaultCrypto.unseal(sealed, key.privateKey, key.publicKey),
      );
    } on CryptoException {
      throw const ExtensionError('app_failed');
    }
    await x.session.write(_declined, null);
  }
}
