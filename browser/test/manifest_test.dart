import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  for (final target in ['chromium', 'firefox', 'safari']) {
    test('$target has the clipboard cleanup background permissions', () async {
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'tool/manifest.dart',
        target,
        '0.1.3',
      ]);
      expect(result.exitCode, 0, reason: result.stderr as String);
      final manifest =
          jsonDecode(result.stdout as String) as Map<String, Object?>;
      final permissions = (manifest['permissions']! as List).cast<String>();
      expect(permissions, containsAll(['alarms', 'clipboardWrite']));
      expect(manifest['background'], isA<Map>());
      if (target == 'chromium') {
        expect(permissions, contains('offscreen'));
      } else {
        expect(permissions, isNot(contains('offscreen')));
      }
      if (target == 'safari') {
        expect(permissions, isNot(contains('clipboardRead')));
        expect(permissions, isNot(contains('nativeMessaging')));
      } else {
        expect(permissions, contains('clipboardRead'));
      }
    });
  }
}
