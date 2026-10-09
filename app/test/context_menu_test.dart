import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixora/src/widgets/common.dart';

/// Every input offers its context menu with "paste": a null builder would
/// switch the menu off.
void main() {
  for (final password in [false, true]) {
    testWidgets('dialog field (password: $password) has a context menu', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  askText(context, title: 'Titel', password: password),
              child: const Text('öffnen'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('öffnen'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.contextMenuBuilder, isNotNull);
      await tester.tapAt(
        tester.getCenter(find.byType(TextField)),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    });
  }
}
