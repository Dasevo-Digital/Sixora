import 'package:sixora_core/sixora_core.dart';
import 'package:test/test.dart';

void main() {
  test('an unknown host name is reported as a DNS problem', () async {
    // .invalid never resolves (RFC 2606).
    final api = SixoraApi(Uri.parse('https://sixora.example.invalid'));
    await expectLater(
      api.info(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'dns')
            .having((e) => e.offline, 'offline', true)
            .having(
              (e) => e.message,
              'message',
              contains('sixora.example.invalid'),
            ),
      ),
    );
    api.close();
  });

  test('base urls get a scheme and a trailing slash', () {
    expect(
      SixoraApi.normalizeBaseUrl(
        Uri.parse('https://sixora.example.org'),
      ).toString(),
      'https://sixora.example.org/',
    );
    expect(
      SixoraApi.normalizeBaseUrl(
        Uri.parse('http://192.168.1.20:8080/sub?x=1#y'),
      ).toString(),
      'http://192.168.1.20:8080/sub/',
    );
    expect(SixoraApi.isLocalHost('192.168.1.20'), isTrue);
    expect(SixoraApi.isLocalHost('sixora.example.org'), isFalse);
    for (final host in [
      'localhost',
      'nas.local',
      '127.0.0.1',
      '10.1.2.3',
      '172.16.0.1',
      '172.31.255.1',
      '169.254.1.1',
      '::1',
      '[::1]',
      'fe80::1',
      'fd12:3456::1',
    ]) {
      expect(SixoraApi.isLocalHost(host), isTrue, reason: host);
    }
    for (final host in [
      '8.8.8.8',
      '172.32.0.1',
      '2001:db8::1',
      '192.169.0.1',
    ]) {
      expect(SixoraApi.isLocalHost(host), isFalse, reason: host);
    }
  });
}
