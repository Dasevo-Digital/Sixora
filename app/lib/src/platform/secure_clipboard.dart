import 'dart:io';

import 'package:flutter/services.dart';

/// Copies codes so that the system treats them as secrets:
///
/// * iOS: only on this device (no Universal Clipboard), expires by itself.
/// * macOS: marked concealed and transient, so clipboard managers skip it
///   (nspasteboard.org conventions).
/// * Android: marked sensitive; the clipboard preview shows dots.
/// * Windows: excluded from clipboard history and cloud clipboard.
/// * Linux: no standard for this; a normal copy.
abstract final class SecureClipboard {
  static const _channel = MethodChannel('sixora/clipboard');

  /// Whether the system removes the text itself after [copy]'s expiry.
  static bool get expiresBySystem => Platform.isIOS;

  static Future<void> copy(
    String text, {
    Duration expiresIn = const Duration(seconds: 30),
  }) async {
    if (Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isAndroid ||
        Platform.isWindows) {
      try {
        await _channel.invokeMethod<void>('copySensitive', {
          'text': text,
          'expiresIn': expiresIn.inSeconds,
        });
        return;
      } on MissingPluginException {
        // fall through
      } on PlatformException {
        // fall through
      }
    }
    await Clipboard.setData(ClipboardData(text: text));
  }
}
