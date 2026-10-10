import 'package:sixora_browser/src/format.dart';
import 'package:sixora_core/sixora_core.dart';
import 'package:test/test.dart';

void main() {
  test('codes are grouped like in the apps', () {
    expect(groupCode('123456'), '123 456');
    expect(groupCode('12345678'), '1234 5678');
    expect(groupCode('XN2W7'), 'XN2W7');
  });

  test('the host permission covers the server, without a port', () {
    expect(
      hostPattern(Uri.parse('https://sixora.example.org/')),
      'https://sixora.example.org/*',
    );
    expect(
      hostPattern(Uri.parse('http://192.168.1.5:8080/')),
      'http://192.168.1.5/*',
    );
    expect(
      hostPattern(Uri.parse('http://[fd00::5]:8080/')),
      'http://[fd00::5]/*',
    );
  });

  test('only web pages have a site to match', () {
    expect(siteOf('https://github.com/login'), 'github.com');
    expect(siteOf('moz-extension://abc/popup.html'), isNull);
    expect(siteOf('chrome://extensions'), isNull);
    expect(siteOf(null), isNull);
  });

  test('seconds left and the avatar colour', () {
    const e = OtpEntry(
      issuer: 'GitHub',
      account: '',
      secret: 'JBSWY3DPEHPK3PXP',
    );
    expect(secondsLeft(e, DateTime.utc(2026, 1, 1, 0, 0, 5)), 25);
    expect(avatarColor(e), startsWith('hsl('));
    expect(avatarColor(e.copyWith(color: () => 0xFF1E88E5)), '#1e88e5');
  });
}
