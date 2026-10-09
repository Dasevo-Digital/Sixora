import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Landing page and security headers.
void main() {
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.start();
  });
  tearDown(() => h.stop());

  group('landing page and headers', () {
    Future<HttpClientResponse> get(
      String path, {
      Map<String, String>? headers,
    }) async {
      final client = HttpClient();
      final request = await client.getUrl(h.url.resolve(path));
      headers?.forEach(request.headers.set);
      final response = await request.close();
      client.close();
      return response;
    }

    test('serves an escaped page whose style matches the policy', () async {
      await h.stop();
      h = Harness();
      await h.start(serverName: '<b>Firma & Co</b>', trustProxy: true);
      final response = await get(
        '/',
        headers: {'X-Forwarded-Proto': 'https', 'Host': 'otp.example.org'},
      );
      final html = await utf8.decodeStream(response);
      expect(response.statusCode, 200);
      expect(response.headers.contentType?.mimeType, 'text/html');
      expect(html, contains('&lt;b&gt;Firma &amp; Co&lt;'));
      expect(html, isNot(contains('<b>Firma')));
      // The address is escaped too ("/" → "&#47;"), browsers show it plainly.
      expect(html, contains('<code>https:&#47;&#47;otp.example.org</code>'));
      expect(html, isNot(contains('<script')));
      final style = RegExp(
        r'<style>(.*?)</style>',
        dotAll: true,
      ).firstMatch(html)!.group(1)!;
      final hash = base64.encode(sha256.convert(utf8.encode(style)).bytes);
      final csp = response.headers.value('content-security-policy')!;
      expect(csp, contains("style-src 'sha256-$hash'"));
      expect(csp, contains("default-src 'none'"));
      expect(csp, contains("frame-ancestors 'none'"));
    });

    test('security headers everywhere, nothing about the technology', () async {
      for (final path in ['/', '/api/v1/info', '/nope']) {
        final r = await get(path);
        await r.drain<void>();
        expect(r.headers.value('x-powered-by'), isNull, reason: path);
        expect(r.headers.value('x-content-type-options'), 'nosniff');
        expect(r.headers.value('x-frame-options'), 'DENY');
        expect(r.headers.value('cache-control'), 'no-store');
        expect(r.headers.value('cross-origin-opener-policy'), 'same-origin');
        expect(r.headers.value('x-robots-tag'), contains('noindex'));
        expect(r.headers.value('permissions-policy'), contains('camera=()'));
      }
      final api = await get('/api/v1/info');
      await api.drain<void>();
      expect(
        api.headers.value('content-security-policy'),
        "default-src 'none'; frame-ancestors 'none'",
      );
      final robots = await get('/robots.txt');
      expect(await utf8.decodeStream(robots), contains('Disallow: /'));
    });
  });
}
