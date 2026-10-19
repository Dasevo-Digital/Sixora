import 'dart:convert';

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

/// "Mit Touch ID entsperren": the extension asks the desktop app (see
/// [BrowserLink]), which confirms with Touch ID, Windows Hello or a dialog
/// and sends the user key sealed to a one-time key of the extension.
///
/// The one-time key waits in `storage.session`, so an answer that arrives
/// after the popup closed (Touch ID takes the focus) still unlocks the next
/// popup ([resume]).
class AppUnlock {
  AppUnlock(this.x, this.ask, {required this.browser});

  final SixoraExtension x;
  final AskApp ask;

  /// Shown in the app, e.g. "Opera".
  final String browser;

  static const _pending = 'appUnlock';
  static const _reply = 'appUnlockReply';

  /// Not asked again on its own after the user declined, until the next
  /// unlock.
  static const _declined = 'appUnlockDeclined';

  /// How the app confirms: "Touch ID", "Windows Hello", "" (a dialog in
  /// the app); null when no app on this computer can unlock this account.
  Future<String?> method() async {
    final s = x.stored;
    if (s == null) return null;
    final hello = await ask({
      'type': 'hello',
    }, timeout: const Duration(seconds: 4));
    if (hello['sixora'] != 1 ||
        hello['available'] != true ||
        !BrowserLink.sameAccount(hello, s.server, s.account.id)) {
      return null;
    }
    return hello['method'] as String? ?? '';
  }

  /// Whether to ask right away when the popup opens.
  Future<bool> get declined async => await x.session.read(_declined) != null;

  /// Asks the app; [onCode] gets the code to show while it waits.
  Future<void> unlock({void Function(String code)? onCode}) async {
    final s = x.stored!;
    final keys = await VaultCrypto.newKeyPair();
    await x.session.write(_reply, null);
    await x.session.write(
      _pending,
      jsonEncode({
        'publicKey': keys.publicKey,
        'privateKey': base64.encode(keys.privateKey),
      }),
    );
    onCode?.call(BrowserLink.code(keys.publicKey));
    final reply = await ask(
      {
        'type': 'unlock',
        'server': s.server.toString(),
        'userId': s.account.id,
        'publicKey': keys.publicKey,
        'browser': browser,
      },
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
    final pendingText = await x.session.read(_pending);
    await cancel();
    if (pendingText == null) throw const ExtensionError('app_cancelled');
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
    final pending = (jsonDecode(pendingText) as Map).cast<String, Object?>();
    try {
      final userKey = await VaultCrypto.unseal(
        sealed,
        base64.decode(pending['privateKey']! as String),
        pending['publicKey']! as String,
      );
      await x.unlockWithUserKey(userKey);
    } on CryptoException {
      throw const ExtensionError('app_failed');
    }
    await x.session.write(_declined, null);
  }
}
