import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sixora/src/platform/browser_link_server.dart';
import 'package:sixora_core/sixora_core.dart';

class _App implements BrowserLinkDelegate {
  final key = Uint8List.fromList(List.generate(32, (i) => 255 - i));
  @override
  ({Uri server, String userId})? get account =>
      (server: Uri.parse('https://sixora.example.org/'), userId: 'u1');
  bool open = true;
  bool connected = true;
  int approvals = 0;
  @override
  bool get unlocked => open;
  @override
  bool get unlockWhileLocked => false;
  @override
  String? get method => null;
  @override
  Uint8List? get userKeyWhileUnlocked => open ? Uint8List.fromList(key) : null;
  @override
  bool isPaired(String publicKey) => connected;
  @override
  Future<String?> get appKey async => null;
  @override
  Future<bool> openWith(String sealedUserKey) async => false;
  @override
  Future<Uint8List?> approve({required String browser}) async {
    approvals++;
    return Uint8List.fromList(key);
  }

  @override
  Future<Uint8List?> pair({
    required String publicKey,
    required String code,
    required String browser,
  }) async => Uint8List.fromList(key);
}

/// The app's end of the link to the browser extension.
void main() {
  late Directory home;

  setUp(() {
    home = Directory.systemTemp.createTempSync('sixora-hosts');
    NativeHosts.homeForTests = home.path;
    // Never the port of an installed Sixora.
    BrowserLinkServer.portForTests = 0;
  });

  tearDown(() {
    NativeHosts.homeForTests = null;
    BrowserLinkServer.portForTests = null;
    home.deleteSync(recursive: true);
  });

  test('answers framed requests on 127.0.0.1', () async {
    final app = _App();
    final link = BrowserLinkServer(BrowserLinkHost(app, version: 'test'));
    // Only a browser folder that exists gets a manifest.
    await link.setEnabled(true);
    addTearDown(() => link.setEnabled(false));

    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      link.boundPort!,
    );
    addTearDown(socket.destroy);
    final replies = StreamController<Map<String, Object?>>();
    final reader = FrameReader();
    socket.listen((data) => reader.add(data).forEach(replies.add));
    final answers = StreamIterator(replies.stream);

    final ext = await VaultCrypto.newKeyPair();
    socket.add(
      BrowserLink.frame({
        'type': 'hello',
        'account': BrowserLink.accountTag(
          Uri.parse('https://sixora.example.org'),
          'u1',
        ),
        'publicKey': ext.publicKey,
      }),
    );
    expect(await answers.moveNext(), isTrue);
    expect(answers.current['ready'], isTrue);

    socket.add(
      BrowserLink.frame({
        'type': 'unlock',
        'account': BrowserLink.accountTag(
          Uri.parse('https://sixora.example.org'),
          'u1',
        ),
        'publicKey': ext.publicKey,
        'browser': 'Opera',
      }),
    );
    expect(await answers.moveNext(), isTrue);
    final key = await VaultCrypto.unseal(
      answers.current['sealedUserKey']! as String,
      ext.privateKey,
      ext.publicKey,
    );
    expect(key, app.key);
  });

  group('a connected extension follows the app', () {
    late _App app;
    late BrowserLinkHost host;
    late ({String publicKey, Uint8List privateKey}) keys;
    Map<String, Object?> request(String type) => {
      'type': type,
      'publicKey': keys.publicKey,
      'account': BrowserLink.accountTag(app.account!.server, 'u1'),
    };

    setUp(() async {
      app = _App();
      host = BrowserLinkHost(app, version: 'test');
      keys = await VaultCrypto.newKeyPair();
    });

    test('unlocked app: the key without asking, sealed to it', () async {
      final hello = await host.handle(request('hello'));
      expect(hello['unlocked'], isTrue);
      final reply = await host.handle(request('session'));
      expect(
        await VaultCrypto.unseal(
          reply['sealedUserKey']! as String,
          keys.privateKey,
          keys.publicKey,
        ),
        app.key,
      );
      expect(app.approvals, 0);
    });

    test('locked app: no key, and the extension hears of it', () async {
      app.open = false;
      expect((await host.handle(request('hello')))['unlocked'], isFalse);
      expect(await host.handle(request('session')), {'error': 'locked'});
    });

    test('not connected: nothing, not even the state', () async {
      app.connected = false;
      expect(
        (await host.handle(request('hello'))).containsKey('unlocked'),
        isFalse,
      );
      expect(await host.handle(request('session')), {'error': 'not_paired'});
    });

    test('another account gets nothing', () async {
      expect(await host.handle({...request('session'), 'account': 'fremd'}), {
        'error': 'other_account',
      });
    });
  });

  test('host manifests go only to installed browsers', () async {
    if (Platform.isWindows) return;
    final firefox = NativeHosts.folders.last;
    final chrome = NativeHosts.folders.first;
    Directory(
      p.join(home.path, p.dirname(firefox)),
    ).createSync(recursive: true);
    Directory(p.join(home.path, p.dirname(chrome))).createSync(recursive: true);

    expect(await NativeHosts.install(), [
      if (Platform.isMacOS) 'Chrome, Opera' else 'Chrome',
      'Firefox',
    ]);
    final file = '${BrowserLink.hostName}.json';
    final ff =
        jsonDecode(File(p.join(home.path, firefox, file)).readAsStringSync())
            as Map;
    expect(ff['allowed_extensions'], [BrowserLink.firefoxId]);
    expect(ff['type'], 'stdio');
    final cr =
        jsonDecode(File(p.join(home.path, chrome, file)).readAsStringSync())
            as Map;
    expect(cr['allowed_origins'], [
      'chrome-extension://${BrowserLink.chromiumId}/',
    ]);
    expect(cr['path'], NativeHosts.program);
    // No folder for browsers that are not there.
    expect(
      Directory(p.join(home.path, NativeHosts.folders[1])).existsSync(),
      isFalse,
    );

    await NativeHosts.remove();
    expect(File(p.join(home.path, firefox, file)).existsSync(), isFalse);
    expect(File(p.join(home.path, chrome, file)).existsSync(), isFalse);
  });
}
