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
  @override
  bool get unlocked => true;
  @override
  bool get unlockWhileLocked => false;
  @override
  String? get method => null;
  @override
  bool isPaired(String publicKey) => true;
  @override
  Future<Uint8List?> approve({required String browser}) async =>
      Uint8List.fromList(key);
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
