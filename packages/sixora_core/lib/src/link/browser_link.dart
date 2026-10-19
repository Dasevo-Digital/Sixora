import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;

import '../api/api_client.dart';
import '../crypto/vault_crypto.dart';

/// Unlocking the browser extension with the desktop app: "Mit Touch ID
/// entsperren" in the extension, confirmed in Sixora.
///
/// The extension asks through the browser's native messaging. The browser
/// starts the Sixora binary as its host, which passes the bytes on to the
/// running app on 127.0.0.1 ([ports]) and back. Both legs use the framing of
/// native messaging: a 4-byte little-endian length, then UTF-8 JSON.
///
/// The app answers an unlock request only after the user confirms it (Touch
/// ID, Windows Hello or a dialog) and then hands out the user key sealed to
/// a one-time key of the extension: the relay and anything listening in see
/// only ciphertext. Both sides show [code], so the user can tell that the
/// request comes from their browser and not from another program.
abstract final class BrowserLink {
  /// Name of the native messaging host (manifest file and registry key).
  static const hostName = 'de.status403.sixora';

  /// Where the apps listen: Sixora, Sixora Dev, the test build. The relay
  /// takes the first one that answers.
  static const ports = [41950, 41951, 41952];

  /// Chromium's ID of the extension (from the key in its manifest).
  static const chromiumId = 'dgnhcjdoiadiehcdiimmkopdhpkgfbek';

  /// Firefox's ID of the extension.
  static const firefoxId = '{8f8c1986-faf4-48a3-a267-a6c28c12f5ec}';

  static const maxMessage = 64 * 1024;

  /// How long the app waits for the user to confirm.
  static const confirmTimeout = Duration(minutes: 2);

  static Uint8List frame(Map<String, Object?> message) {
    final body = utf8.encode(jsonEncode(message));
    final bytes = Uint8List(4 + body.length);
    ByteData.sublistView(bytes).setUint32(0, body.length, Endian.little);
    bytes.setRange(4, bytes.length, body);
    return bytes;
  }

  /// Six digits derived from the extension's one-time key, e.g. "482 913".
  static String code(String publicKeyB64) {
    final digest = c.sha256
        .convert(utf8.encode('sixora-browser-link|$publicKeyB64'))
        .bytes;
    final n =
        ByteData.sublistView(Uint8List.fromList(digest)).getUint32(0) % 1000000;
    final s = n.toString().padLeft(6, '0');
    return '${s.substring(0, 3)} ${s.substring(3)}';
  }

  /// Whether the app and the extension use the same account.
  static bool sameAccount(
    Map<String, Object?> hello,
    Uri server,
    String userId,
  ) {
    final appServer = Uri.tryParse(hello['server'] as String? ?? '');
    return appServer != null &&
        hello['userId'] == userId &&
        SixoraApi.normalizeBaseUrl(appServer) ==
            SixoraApi.normalizeBaseUrl(server);
  }
}

/// Splits a byte stream into framed messages.
class FrameReader {
  final _buffer = BytesBuilder(copy: false);

  /// Adds received bytes and returns the messages that are complete.
  List<Map<String, Object?>> add(List<int> bytes) {
    _buffer.add(bytes);
    final data = _buffer.takeBytes();
    final messages = <Map<String, Object?>>[];
    var offset = 0;
    while (data.length - offset >= 4) {
      final length = ByteData.sublistView(
        data,
        offset,
        offset + 4,
      ).getUint32(0, Endian.little);
      if (length > BrowserLink.maxMessage) {
        throw const FormatException('Nachricht zu groß');
      }
      if (data.length - offset - 4 < length) break;
      final message = jsonDecode(
        utf8.decode(data.sublist(offset + 4, offset + 4 + length)),
      );
      if (message is! Map) throw const FormatException('Keine Nachricht');
      messages.add(message.cast());
      offset += 4 + length;
    }
    _buffer.add(data.sublist(offset));
    return messages;
  }
}

/// What the app tells the link about itself, and how it asks the user.
abstract interface class BrowserLinkDelegate {
  /// The signed-in account; null without one (or in local mode).
  ({Uri server, String userId})? get account;

  bool get unlocked;

  /// Whether the user key is reachable while the app is locked (quick
  /// unlock with biometrics).
  bool get unlockWhileLocked;

  /// "Touch ID", "Windows Hello"; null when the app confirms with a
  /// dialog.
  String? get method;

  /// Asks the user to confirm (showing [code]) and returns the user key,
  /// or null if they decline.
  Future<Uint8List?> approve({required String code, required String browser});
}

/// The app's side: answers `hello` and `unlock` requests.
class BrowserLinkHost {
  BrowserLinkHost(this.delegate, {required this.version});

  final BrowserLinkDelegate delegate;
  final String version;
  bool _busy = false;

  Future<Map<String, Object?>> handle(Map<String, Object?> request) async {
    switch (request['type']) {
      case 'hello':
        final account = delegate.account;
        return {
          'sixora': 1,
          'version': version,
          'server': account?.server.toString(),
          'userId': account?.userId,
          'unlocked': delegate.unlocked,
          'available':
              account != null &&
              (delegate.unlocked || delegate.unlockWhileLocked),
          'method': delegate.method,
        };
      case 'unlock':
        return _unlock(request);
      default:
        return {'error': 'unknown'};
    }
  }

  Future<Map<String, Object?>> _unlock(Map<String, Object?> request) async {
    final account = delegate.account;
    final publicKey = request['publicKey'];
    final server = Uri.tryParse(request['server'] as String? ?? '');
    if (publicKey is! String || server == null) return {'error': 'invalid'};
    try {
      if (base64.decode(publicKey).length != 32) return {'error': 'invalid'};
    } on FormatException {
      return {'error': 'invalid'};
    }
    if (account == null ||
        !BrowserLink.sameAccount(
          {'server': account.server.toString(), 'userId': account.userId},
          server,
          request['userId'] as String? ?? '',
        )) {
      return {'error': 'other_account'};
    }
    if (!delegate.unlocked && !delegate.unlockWhileLocked) {
      return {'error': 'locked'};
    }
    if (_busy) return {'error': 'busy'};
    _busy = true;
    try {
      final browser = request['browser'];
      final key = await delegate
          .approve(
            code: BrowserLink.code(publicKey),
            browser: browser is String && browser.length <= 40
                ? browser
                : 'Browser',
          )
          .timeout(BrowserLink.confirmTimeout, onTimeout: () => null);
      if (key == null) return {'error': 'denied'};
      try {
        return {'sealedUserKey': await VaultCrypto.seal(key, publicKey)};
      } finally {
        key.fillRange(0, key.length, 0);
      }
    } finally {
      _busy = false;
    }
  }
}
