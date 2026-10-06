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
        Uri.parse('http://192.168.10.67:8080/sub?x=1#y'),
      ).toString(),
      'http://192.168.10.67:8080/sub/',
    );
    expect(SixoraApi.isLocalHost('192.168.10.67'), isTrue);
    expect(SixoraApi.isLocalHost('sixora.example.org'), isFalse);
  });
}
