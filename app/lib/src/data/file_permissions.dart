import 'dart:io';

bool get _posixDesktop => Platform.isLinux || Platform.isMacOS;

Future<void> ensurePrivateDirectory(Directory directory) async {
  await directory.create(recursive: true);
  if (_posixDesktop) await _chmod(directory.path, '700');
}

Future<void> ensurePrivateFile(File file) async {
  if (_posixDesktop) await _chmod(file.path, '600');
}

Future<void> _chmod(String path, String mode) async {
  final result = await Process.run('chmod', [mode, path]);
  if (result.exitCode != 0) {
    throw FileSystemException('Dateirechte konnten nicht gesetzt werden', path);
  }
}
