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
/// Every program on the computer can reach that port, so the app trusts
/// only extensions the user connected once ("pairing"): the extension has a
/// key pair of its own, and the first request makes the app ask whether to
/// connect it, showing [code] of its public key – the extension shows the
/// same code. Afterwards a confirmation with Touch ID, Windows Hello or a
/// dialog is enough, and the user key goes out only sealed to a connected
/// key: another program can claim one, but cannot open the answer. `hello`
/// tells nothing about the account; the extension asks whether it is the
/// same.
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

  /// Version of the requests and answers below.
  static const protocol = 2;

  /// Names the account without giving it away: whoever listens on the
  /// port learns neither server nor user.
  static String accountTag(Uri server, String userId) => base64.encode(
    c.sha256
        .convert(
          utf8.encode(
            'sixora-browser-link|${SixoraApi.normalizeBaseUrl(server)}|$userId',
          ),
        )
        .bytes,
  );

  /// After the user declined to connect an extension, new requests to
  /// connect are refused for this long: no dialog after dialog.
  static const pairingPause = Duration(minutes: 1);
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

  /// Whether the user connected the extension with this key.
  bool isPaired(String publicKey);

  /// A connected extension: the user confirms; the user key, or null.
  Future<Uint8List?> approve({required String browser});

  /// A new extension: the app asks whether to connect it, showing [code]
  /// (the extension shows it too). On yes it remembers [publicKey] and
  /// returns the user key. Only while the app is unlocked.
  Future<Uint8List?> pair({
    required String publicKey,
    required String code,
    required String browser,
  });
}

/// The app's side: answers `hello` and `unlock` requests.
class BrowserLinkHost {
  BrowserLinkHost(
    this.delegate, {
    required this.version,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final BrowserLinkDelegate delegate;
  final String version;
  final DateTime Function() _clock;
  bool _busy = false;
  DateTime? _pairingPausedUntil;

  Future<Map<String, Object?>> handle(Map<String, Object?> request) async {
    switch (request['type']) {
      case 'hello':
        final same = _sameAccount(request);
        final key = _publicKey(request);
        final paired = same && key != null && delegate.isPaired(key);
        return {
          'sixora': BrowserLink.protocol,
          'version': version,
          'sameAccount': same,
          'paired': paired,
          // Whether a request would reach the user now.
          'ready':
              same &&
              (delegate.unlocked || (paired && delegate.unlockWhileLocked)),
          'method': delegate.method,
        };
      case 'unlock':
        return _unlock(request);
      default:
        return {'error': 'unknown'};
    }
  }

  bool _sameAccount(Map<String, Object?> request) {
    final account = delegate.account;
    final tag = request['account'];
    return account != null &&
        tag is String &&
        tag == BrowserLink.accountTag(account.server, account.userId);
  }

  static String? _publicKey(Map<String, Object?> request) {
    final key = request['publicKey'];
    if (key is! String) return null;
    try {
      return base64.decode(key).length == 32 ? key : null;
    } on FormatException {
      return null;
    }
  }

  Future<Map<String, Object?>> _unlock(Map<String, Object?> request) async {
    final publicKey = _publicKey(request);
    if (publicKey == null) return {'error': 'invalid'};
    if (!_sameAccount(request)) return {'error': 'other_account'};
    final paired = delegate.isPaired(publicKey);
    if (!delegate.unlocked && !(paired && delegate.unlockWhileLocked)) {
      return {'error': 'locked'};
    }
    if (_busy) return {'error': 'busy'};
    final pause = _pairingPausedUntil;
    if (!paired && pause != null && _clock().isBefore(pause)) {
      return {'error': 'denied'};
    }
    _busy = true;
    try {
      final name = request['browser'];
      final browser = name is String && name.isNotEmpty && name.length <= 40
          ? name
          : 'Browser';
      final key =
          await (paired
                  ? delegate.approve(browser: browser)
                  : delegate.pair(
                      publicKey: publicKey,
                      code: BrowserLink.code(publicKey),
                      browser: browser,
                    ))
              .timeout(BrowserLink.confirmTimeout, onTimeout: () => null);
      if (key == null) {
        if (!paired) {
          _pairingPausedUntil = _clock().add(BrowserLink.pairingPause);
        }
        return {'error': 'denied'};
      }
      try {
        return {
          'sealedUserKey': await VaultCrypto.seal(key, publicKey),
          'paired': true,
        };
      } finally {
        key.fillRange(0, key.length, 0);
      }
    } finally {
      _busy = false;
    }
  }
}
