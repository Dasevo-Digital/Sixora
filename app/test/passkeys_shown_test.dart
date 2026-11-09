import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixora/src/data/app_controller.dart';
import 'package:sixora/src/data/local_store.dart';
import 'package:sixora/src/l10n.dart';
import 'package:sixora/src/screens/settings_screen.dart';
import 'package:sixora/src/widgets/common.dart';
import 'package:sixora_core/sixora_core.dart';

void main() {
  // The settings page is only filled in for a signed-in account.
  final account = CachedAccount(
    server: Uri.parse('https://sixora.example/'),
    serverName: 'Testserver',
    account: const AccountBundle(
      id: 'user',
      username: 'alice',
      isAdmin: false,
      kdf: {},
      salt: '',
      wrappedUserKey: '',
      publicKey: '',
      encryptedPrivateKey: '',
    ),
  );

  setUp(() => useLocale(const Locale('de')));

  for (final (platform, shown) in [
    (TargetPlatform.iOS, false),
    (TargetPlatform.android, true),
    (TargetPlatform.macOS, true),
    (TargetPlatform.windows, true),
    (TargetPlatform.linux, true),
  ]) {
    testWidgets('settings on ${platform.name} list passkeys: $shown', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('sixora-passkeys-shown');
      addTearDown(() => dir.deleteSync(recursive: true));
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1;
      debugDefaultTargetPlatformOverride = platform;

      await tester.pumpWidget(
        MaterialApp(
          home: AppScope(
            controller: AppController.forTest(dir, cached: account),
            child: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      // The recycle bin sits right below: the list really was built.
      expect(find.text(t.trash), findsOneWidget);
      expect(find.text(t.passkeys), shown ? findsOneWidget : findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
