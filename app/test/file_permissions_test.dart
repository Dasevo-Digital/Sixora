import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixora/src/data/file_permissions.dart';

void main() {
  test('desktop data paths receive explicit private modes', () async {
    if (!Platform.isLinux && !Platform.isMacOS) return;
    final parent = await Directory.systemTemp.createTemp('sixora-modes');
    addTearDown(() => parent.delete(recursive: true));
    final dir = Directory('${parent.path}/data');
    await ensurePrivateDirectory(dir);
    final file = File('${dir.path}/settings.json');
    await file.writeAsString('{}');
    await ensurePrivateFile(file);
    expect(dir.statSync().mode & 0x1ff, 0x1c0);
    expect(file.statSync().mode & 0x1ff, 0x180);
  });
}
