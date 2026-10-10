import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixora/src/autofill/autofill.dart';
import 'package:sixora/src/autofill/autofill_app.dart';
import 'package:sixora/src/data/app_controller.dart';
import 'package:sixora/src/widgets/common.dart';
import 'package:sixora_core/sixora_core.dart';

OtpEntry entry(String issuer, {OtpType type = OtpType.totp}) => OtpEntry(
  issuer: issuer,
  account: 'alice@example.org',
  secret: 'JBSWY3DPEHPK3PXP',
  type: type,
);

Item item(String issuer, {OtpType type = OtpType.totp}) =>
    Item(issuer, 'vault', 1, entry(issuer, type: type));

/// Android autofill: which accounts fit the asking app or website.
void main() {
  test('the service name comes from the website or the app', () {
    expect(const AutofillRequest(domain: 'github.com').words, {'github'});
    expect(const AutofillRequest(domain: 'accounts.google.com').words, {
      'google',
    });
    expect(const AutofillRequest(package: 'com.github.android').words, {
      'github',
    });
    // In a browser only the website counts, not the browser's own name.
    expect(
      const AutofillRequest(
        domain: 'gitlab.com',
        package: 'com.android.chrome',
      ).words,
      {'gitlab'},
    );
  });

  test('accounts match by their service name', () {
    bool fits(String issuer, {String? domain, String? package}) =>
        AutofillRequest(
          domain: domain,
          package: package,
        ).matches(entry(issuer));
    expect(fits('GitHub', domain: 'github.com'), isTrue);
    expect(fits('Google', domain: 'accounts.google.com'), isTrue);
    expect(fits('Microsoft', domain: 'login.microsoftonline.com'), isTrue);
    expect(fits('AWS', domain: 'signin.aws.amazon.com'), isTrue);
    expect(
      fits('Amazon Web Services', domain: 'signin.aws.amazon.com'),
      isTrue,
    );
    expect(fits('Nextcloud', package: 'com.nextcloud.client'), isTrue);
    expect(fits('GitLab', domain: 'github.com'), isFalse);
    expect(fits('X', domain: 'x.com'), isFalse);
    expect(fits('GitHub', package: 'com.android.chrome'), isFalse);
  });

  test('HOTP accounts are left out, matching ones come first', () {
    final choices = autofillChoices([
      item('GitLab'),
      item('GitHub'),
      item('Counter', type: OtpType.hotp),
      item('Steam', type: OtpType.steam),
    ], const AutofillRequest(domain: 'github.com'));
    expect([for (final i in choices.matching) i.entry.issuer], ['GitHub']);
    expect(
      [for (final i in choices.others) i.entry.issuer],
      ['GitLab', 'Steam'],
    );
  });

  testWidgets('tapping an account hands its current code to the field', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('sixora-autofill');
    addTearDown(() => dir.deleteSync(recursive: true));
    final controller = AppController.forTest(dir)
      ..items = [item('GitLab'), item('GitHub')];
    String? filled;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('sixora/autofill'),
      (call) async {
        if (call.method == 'fill') filled = call.arguments as String;
        return null;
      },
    );
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(
          home: AutofillScreen(request: AutofillRequest(domain: 'github.com')),
        ),
      ),
    );
    expect(find.text('für github.com'), findsOneWidget);
    expect(find.text('Passend'), findsOneWidget);
    // The matching account stands above the others.
    expect(
      tester.getTopLeft(find.text('GitHub')).dy,
      lessThan(tester.getTopLeft(find.text('GitLab')).dy),
    );
    await tester.tap(find.text('GitHub'));
    await tester.pump();
    expect(filled, matches(RegExp(r'^\d{6}$')));
    expect(filled, item('GitHub').entry.code());
  });
}
