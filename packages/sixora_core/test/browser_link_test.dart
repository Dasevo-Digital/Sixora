import 'dart:typed_data';

import 'package:sixora_core/sixora_core.dart';
import 'package:test/test.dart';

class _App implements BrowserLinkDelegate {
  @override
  ({Uri server, String userId})? account = (
    server: Uri.parse('https://sixora.example.org/'),
    userId: 'u1',
  );
  @override
  bool unlocked = true;
  @override
  bool unlockWhileLocked = false;
  @override
  String? method = 'Touch ID';

  bool approves = true;
  final userKey = Uint8List.fromList(List.generate(32, (i) => i));
  String? shownCode;

  @override
  Future<Uint8List?> approve({
    required String code,
    required String browser,
  }) async {
    shownCode = code;
    return approves ? Uint8List.fromList(userKey) : null;
  }
}

void main() {
  test('messages are framed like native messaging', () {
    final reader = FrameReader();
    final a = BrowserLink.frame({'type': 'hello'});
    final b = BrowserLink.frame({'type': 'unlock', 'n': 2});
    expect(a.sublist(0, 4), [16, 0, 0, 0]);
    final bytes = [...a, ...b];
    // In pieces, as a socket may deliver them.
    expect(reader.add(bytes.sublist(0, 3)), isEmpty);
    expect(reader.add(bytes.sublist(3, 25)), [
      {'type': 'hello'},
    ]);
    expect(reader.add(bytes.sublist(25)), [
      {'type': 'unlock', 'n': 2},
    ]);
    expect(
      () => FrameReader().add([0, 0, 2, 0]),
      throwsA(isA<FormatException>()),
    );
  });

  test('both sides show the same six digits', () async {
    final keys = await VaultCrypto.newKeyPair();
    final code = BrowserLink.code(keys.publicKey);
    expect(code, matches(RegExp(r'^\d{3} \d{3}$')));
    expect(BrowserLink.code(keys.publicKey), code);
    final other = await VaultCrypto.newKeyPair();
    expect(BrowserLink.code(other.publicKey), isNot(code));
  });

  group('the app', () {
    late _App app;
    late BrowserLinkHost host;
    late ({String publicKey, Uint8List privateKey}) ext;
    Map<String, Object?> request({String userId = 'u1'}) => {
      'type': 'unlock',
      'server': 'https://sixora.example.org',
      'userId': userId,
      'publicKey': ext.publicKey,
      'browser': 'Opera',
    };

    setUp(() async {
      app = _App();
      host = BrowserLinkHost(app, version: '0.1.28');
      ext = await VaultCrypto.newKeyPair();
    });

    test('says who it is', () async {
      final hello = await host.handle({'type': 'hello'});
      expect(hello['available'], isTrue);
      expect(hello['method'], 'Touch ID');
      expect(
        BrowserLink.sameAccount(
          hello,
          Uri.parse('https://sixora.example.org'),
          'u1',
        ),
        isTrue,
      );
      expect(
        BrowserLink.sameAccount(
          hello,
          Uri.parse('https://other.example.org'),
          'u1',
        ),
        isFalse,
      );
    });

    test('hands out the user key sealed to the extension', () async {
      final reply = await host.handle(request());
      expect(app.shownCode, BrowserLink.code(ext.publicKey));
      final key = await VaultCrypto.unseal(
        reply['sealedUserKey']! as String,
        ext.privateKey,
        ext.publicKey,
      );
      expect(key, app.userKey);
    });

    test('refuses other accounts, locked apps and declined requests', () async {
      expect(
        (await host.handle(request(userId: 'u2')))['error'],
        'other_account',
      );
      app.unlocked = false;
      expect((await host.handle(request()))['error'], 'locked');
      expect((await host.handle({'type': 'hello'}))['available'], isFalse);
      app.unlockWhileLocked = true;
      app.approves = false;
      expect((await host.handle(request()))['error'], 'denied');
      app.account = null;
      expect((await host.handle(request()))['error'], 'other_account');
      expect(
        (await host.handle({...request(), 'publicKey': 'kurz'}))['error'],
        'invalid',
      );
    });
  });
}
