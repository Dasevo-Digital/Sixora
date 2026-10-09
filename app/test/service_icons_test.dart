import 'package:flutter_test/flutter_test.dart';
import 'package:sixora/src/data/service_icons.dart';
import 'package:sixora_core/sixora_core.dart';

OtpEntry entry(String issuer, {String account = 'me', String? icon}) =>
    OtpEntry(
      issuer: issuer,
      account: account,
      secret: 'JBSWY3DPEHPK3PXP',
      icon: icon,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ServiceIcons icons;
  setUpAll(() async {
    await ServiceIcons.load();
    icons = ServiceIcons.loaded.value!;
  });

  test('the bundle loads and every path parses', () {
    expect(icons.icons.length, greaterThan(3000));
    for (final icon in icons.icons) {
      expect(icon.shape.getBounds().isEmpty, isFalse, reason: icon.slug);
    }
  });

  test('issuers are matched to the right logo', () {
    String? slug(String issuer) => icons.guess(issuer)?.slug;
    expect(slug('Google'), 'google');
    expect(slug('google'), 'google');
    expect(slug('accounts.google.com'), 'google');
    expect(slug('GitHub'), 'github');
    expect(slug('Proton Mail Bridge'), 'protonmail');
    expect(slug('Proton'), 'proton');
    expect(slug('Bitwarden'), 'bitwarden');
    expect(slug('Steam'), 'steam');
    expect(slug('Deutsche Telekom'), 'deutschetelekom');
    expect(slug('X (Twitter)'), 'x');
    expect(slug('Twitter'), 'x');
    expect(slug('Mein Arbeitgeber'), isNull);
    expect(slug(''), isNull);
  });

  test('the choice of the user wins', () {
    expect(icons.forEntry(entry('Google'))?.slug, 'google');
    expect(icons.forEntry(entry('Google', icon: OtpEntry.noIcon)), isNull);
    expect(icons.forEntry(entry('Firma', icon: 'github'))?.slug, 'github');
    // Without issuer the domain of the account helps.
    expect(icons.forEntry(entry('', account: 'me@gitlab.com'))?.slug, 'gitlab');
  });

  test('search finds by prefix first', () {
    final results = icons.search('goog');
    expect(results.first.slug, 'google');
    expect(icons.search('').length, icons.icons.length);
  });
}
