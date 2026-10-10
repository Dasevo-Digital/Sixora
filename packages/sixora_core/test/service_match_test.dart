import 'package:sixora_core/sixora_core.dart';
import 'package:test/test.dart';

OtpEntry entry(String issuer) =>
    OtpEntry(issuer: issuer, account: '', secret: 'JBSWY3DPEHPK3PXP');

void main() {
  test('the service name comes from the website or the app', () {
    expect(ServiceMatch(domain: 'github.com').words, {'github'});
    expect(ServiceMatch(domain: 'accounts.google.com').words, {'google'});
    expect(ServiceMatch(package: 'com.github.android').words, {'github'});
    expect(
      ServiceMatch(domain: 'gitlab.com', package: 'com.android.chrome').words,
      {'gitlab'},
    );
  });

  test('accounts match by their issuer', () {
    bool fits(String issuer, String domain) =>
        ServiceMatch(domain: domain).matches(entry(issuer));
    expect(fits('GitHub', 'github.com'), isTrue);
    expect(fits('Microsoft', 'login.microsoftonline.com'), isTrue);
    expect(fits('Amazon Web Services', 'signin.aws.amazon.com'), isTrue);
    expect(fits('GitLab', 'github.com'), isFalse);
    expect(fits('X', 'x.com'), isFalse);
  });
}
