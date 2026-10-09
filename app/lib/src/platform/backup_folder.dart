import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// A folder the user picked once, for automatic backups. It must stay
/// writable across restarts:
///
/// * macOS, iOS: a (security-scoped) bookmark, so also iCloud Drive and
///   other file providers work.
/// * Android: a document tree with a persisted permission (also cloud
///   providers such as Nextcloud).
/// * Windows, Linux: the plain path.
class FolderRef {
  const FolderRef(this.ref, this.label);
  final String ref;
  final String label;
}

abstract final class BackupFolder {
  static const _channel = MethodChannel('sixora/folder');

  static bool get _nativePick =>
      Platform.isMacOS || Platform.isIOS || Platform.isAndroid;

  /// A plain path also works on macOS (inside the app's own folders).
  static bool _native(String ref) => _nativePick && !ref.startsWith('/');

  static Future<FolderRef?> pick() async {
    if (_nativePick) {
      final r = await _channel.invokeMapMethod<String, Object?>('pick');
      if (r == null) return null;
      return FolderRef(r['ref']! as String, r['label'] as String? ?? '');
    }
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Ordner für die automatische Sicherung',
    );
    return path == null ? null : FolderRef(path, path);
  }

  static Future<void> write(String ref, String name, String text) async {
    if (_native(ref)) {
      await _channel.invokeMethod<void>('write', {
        'ref': ref,
        'name': name,
        'text': text,
      });
      return;
    }
    final file = File(p.join(ref, name));
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(file.path);
  }

  static Future<List<String>> list(String ref) async {
    if (_native(ref)) {
      return (await _channel.invokeListMethod<String>('list', {'ref': ref})) ??
          const [];
    }
    return [
      for (final e in Directory(ref).listSync())
        if (e is File) p.basename(e.path),
    ];
  }

  static Future<String> read(String ref, String name) async {
    if (_native(ref)) {
      return (await _channel.invokeMethod<String>('read', {
        'ref': ref,
        'name': name,
      }))!;
    }
    return File(p.join(ref, name)).readAsString();
  }

  static Future<void> delete(String ref, String name) async {
    if (_native(ref)) {
      await _channel.invokeMethod<void>('delete', {'ref': ref, 'name': name});
      return;
    }
    await File(p.join(ref, name)).delete();
  }
}
