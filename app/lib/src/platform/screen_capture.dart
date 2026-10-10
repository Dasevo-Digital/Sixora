import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../data/app_controller.dart';
import '../l10n.dart';
import 'qr_image.dart';

/// QR codes shown on the screen, e.g. on a service's settings page in the
/// browser: no screenshot file needed.
///
/// * macOS: the user picks a window or display in the system picker (no
///   screen recording permission needed); before macOS 14 an area as with
///   ⌘⇧4. Vision reads it.
/// * Linux: the same with the desktop's own tool (Spectacle, GNOME
///   Screenshot, grim + slurp, scrot).
/// * Windows: the whole screen, read by the Dart decoder.
///
/// Sixora's window steps aside meanwhile, so it does not cover the code.
abstract final class ScreenCapture {
  static const _channel = MethodChannel('sixora/screen');

  static bool get supported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// What happens after the tap, for the menu entry.
  static String get hint => Platform.isMacOS
      ? t.qrFromScreenWindowHint
      : Platform.isWindows
      ? t.qrFromScreenWholeHint
      : t.qrFromScreenAreaHint;

  /// The codes found; null if the user cancelled the selection.
  static Future<List<String>?> readQrCodes() async {
    await windowManager.hide();
    // The window needs a moment to disappear from the screen.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    try {
      if (Platform.isWindows) {
        final shot = await _channel.invokeMapMethod<String, Object?>('capture');
        if (shot == null) return null;
        final code = await readQrPixels(
          shot['width']! as int,
          shot['height']! as int,
          shot['pixels']! as Uint8List,
        );
        return [?code];
      }
      final file = Platform.isMacOS ? await _pickMac() : await _captureArea();
      if (file == null) return null;
      try {
        return await readQrImages([(path: file.path, bytes: file.readAsBytes)]);
      } finally {
        if (file.existsSync()) file.deleteSync();
      }
    } finally {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  static Future<File?> _pickMac() async {
    try {
      final path = await _channel.invokeMethod<String>('pick');
      return path == null ? null : File(path);
    } on MissingPluginException {
      return _captureArea();
    }
  }

  static Future<File?> _captureArea() async {
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(
        dir.path,
        'sixora-screen-${DateTime.now().millisecondsSinceEpoch}.png',
      ),
    );
    if (Platform.isMacOS) {
      // -i: area (space: a window), Esc cancels; -x: no sound.
      await Process.run('/usr/sbin/screencapture', ['-i', '-x', file.path]);
      return file.existsSync() ? file : null;
    }
    final tools = <(String, List<String>)>[
      ('spectacle', ['spectacle', '-b', '-n', '-r', '-o', file.path]),
      ('gnome-screenshot', ['gnome-screenshot', '-a', '-f', file.path]),
      ('slurp', ['sh', '-c', 'grim -g "\$(slurp)" "${file.path}"']),
      ('scrot', ['scrot', '-s', '-o', file.path]),
    ];
    for (final (name, command) in tools) {
      final found = await Process.run('which', [name]);
      if (found.exitCode != 0) continue;
      await Process.run(command.first, command.sublist(1));
      return file.existsSync() ? file : null;
    }
    throw UserError(t.noScreenshotTool);
  }
}
