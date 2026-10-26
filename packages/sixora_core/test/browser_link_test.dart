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
  final paired = <String>{};
  final userKey = Uint8List.fromList(List.generate(32, (i) => i));
  String? pairCode;
  int approvals = 0;

  @override
  bool isPaired(String publicKey) => paired.contains(publicKey);

  @override
  Future<Uint8List?> approve({required String browser}) async {
    approvals++;
    return approves ? Uint8List.fromList(userKey) : null;
  }

  @override
  Future<Uint8List?> pair({
    required String publicKey,
    required String code,
    required String browser,
  }) async {
    pairCode = code;
    if (!approves) return null;
    paired.add(publicKey);
    return Uint8List.fromList(userKey);
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
    var now = DateTime(2026, 10, 26, 12);
    Map<String, Object?> request(String type, {String userId = 'u1'}) => {
      'type': type,
      'account': BrowserLink.accountTag(
        Uri.parse('https://sixora.example.org'),
        userId,
      ),
      'publicKey': ext.publicKey,
      'browser': 'Opera',
    };

    setUp(() async {
      app = _App();
      host = BrowserLinkHost(app, version: '0.1.30', clock: () => now);
      ext = await VaultCrypto.newKeyPair();
    });

    test('tells only whether the account is the same', () async {
      final hello = await host.handle(request('hello'));
      expect(hello['sameAccount'], isTrue);
      expect(hello['paired'], isFalse);
      expect(hello['ready'], isTrue);
      expect(hello.containsKey('server'), isFalse);
      expect(hello.containsKey('userId'), isFalse);
      final other = await host.handle(request('hello', userId: 'u2'));
      expect(other['sameAccount'], isFalse);
      expect(other['ready'], isFalse);
      // Someone else asking without an account learns nothing either.
      expect((await host.handle({'type': 'hello'}))['sameAccount'], isFalse);
    });

    test('connects a new extension once, then Touch ID suffices', () async {
      final first = await host.handle(request('unlock'));
      expect(app.pairCode, BrowserLink.code(ext.publicKey));
      expect(app.approvals, 0);
      expect(
        await VaultCrypto.unseal(
          first['sealedUserKey']! as String,
          ext.privateKey,
          ext.publicKey,
        ),
        app.userKey,
      );
      expect((await host.handle(request('hello')))['paired'], isTrue);

      app.pairCode = null;
      final again = await host.handle(request('unlock'));
      expect(app.pairCode, isNull);
      expect(app.approvals, 1);
      expect(
        await VaultCrypto.unseal(
          again['sealedUserKey']! as String,
          ext.privateKey,
          ext.publicKey,
        ),
        app.userKey,
      );
    });

    test('a locked app opens only for connected extensions', () async {
      app.unlocked = false;
      app.unlockWhileLocked = true;
      // Connecting needs the app unlocked.
      expect((await host.handle(request('unlock')))['error'], 'locked');
      expect((await host.handle(request('hello')))['ready'], isFalse);
      app.paired.add(ext.publicKey);
      expect((await host.handle(request('hello')))['ready'], isTrue);
      expect(
        (await host.handle(request('unlock')))['sealedUserKey'],
        isA<String>(),
      );
      app.unlockWhileLocked = false;
      expect((await host.handle(request('unlock')))['error'], 'locked');
    });

    test('refuses other accounts, declined requests and bad keys', () async {
      expect(
        (await host.handle(request('unlock', userId: 'u2')))['error'],
        'other_account',
      );
      app.approves = false;
      expect((await host.handle(request('unlock')))['error'], 'denied');
      expect(app.paired, isEmpty);
      // No dialog after dialog: a minute without asking again.
      app.approves = true;
      app.pairCode = null;
      expect((await host.handle(request('unlock')))['error'], 'denied');
      expect(app.pairCode, isNull);
      now = now.add(const Duration(minutes: 2));
      expect(
        (await host.handle(request('unlock')))['sealedUserKey'],
        isA<String>(),
      );
      app.approves = false;
      app.account = null;
      expect((await host.handle(request('unlock')))['error'], 'other_account');
      expect(
        (await host.handle({
          ...request('unlock'),
          'publicKey': 'kurz',
        }))['error'],
        'invalid',
      );
    });
  });
}
