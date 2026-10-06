import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixora/src/widgets/common.dart';

void main() {
  void mockClipboard(WidgetTester tester, String text) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => switch (call.method) {
        'Clipboard.getData' => {'text': text},
        'Clipboard.hasStrings' => {'value': true},
        _ => null,
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  testWidgets('a right click pastes into the master password field', (
    tester,
  ) async {
    mockClipboard(tester, 'geheim-123');
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PasswordField(controller: controller)),
      ),
    );

    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      controller.clear();
      await tester.tap(
        find.byType(TextField),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(find.text('Einfügen'), findsOneWidget, reason: '$platform');
      await tester.tap(find.text('Einfügen'));
      await tester.pumpAndSettle();
      expect(controller.text, 'geheim-123', reason: '$platform');
      // Nothing to copy the password out with.
      expect(find.text('Kopieren'), findsNothing);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the paste button fills the field with the trimmed clipboard', (
    tester,
  ) async {
    mockClipboard(tester, '  JBSW Y3DP EHPK 3PXP \n');
    final controller = TextEditingController(text: 'alt');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PasswordField(controller: controller)),
      ),
    );
    await tester.tap(find.byTooltip('Einfügen'));
    await tester.pumpAndSettle();
    expect(controller.text, 'JBSW Y3DP EHPK 3PXP');
  });
}
