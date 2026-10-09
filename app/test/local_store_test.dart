import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixora/src/data/local_store.dart';

void main() {
  test('concurrent saves do not trip over each other', () async {
    final dir = await Directory.systemTemp.createTemp('sixora-store');
    addTearDown(() => dir.delete(recursive: true));
    final store = LocalStore(dir);
    final saves = [
      for (var i = 0; i < 30; i++)
        store.saveSettings(AppSettings()..hideCodes = i.isEven),
    ];
    await Future.wait(saves);
    // The last write wins, and no temporary file is left behind.
    expect(store.loadSettings().hideCodes, isFalse);
    expect(dir.listSync().map((f) => f.uri.pathSegments.last), [
      'settings.json',
    ]);
  });
}
