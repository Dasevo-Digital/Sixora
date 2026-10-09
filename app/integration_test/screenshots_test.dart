// Screenshots for the README: the real app with made-up demo accounts
// against a fresh, empty server. Skipped unless SIXORA_SHOTS is set:
//
//   tool/screenshots.sh            (starts the server, copies the PNGs)
//
// The macOS test app is sandboxed and its container is closed to other
// programs, so the images leave as base64 in "SHOT <name> <chunk>" lines,
// which the script puts back together.
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sixora/src/app.dart';
import 'package:sixora/src/data/app_controller.dart';
import 'package:sixora/src/data/local_store.dart';
import 'package:sixora/src/data/service_icons.dart';
import 'package:sixora/src/environment.dart';
import 'package:sixora/src/screens/entry_editor.dart';
import 'package:sixora/src/screens/home_screen.dart';
import 'package:sixora_core/sixora_core.dart';

const _shots = String.fromEnvironment('SIXORA_SHOTS');
const _server = String.fromEnvironment(
  'SIXORA_TEST_SERVER',
  defaultValue: 'http://127.0.0.1:18081',
);

String _secret(Random r) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  return List.generate(32, (_) => alphabet[r.nextInt(32)]).join();
}

/// Demo accounts; those with [team] go into the shared vault "Team".
List<(OtpEntry, {bool team})> _demo(Random r) {
  (OtpEntry, {bool team}) e(
    String issuer,
    String account, {
    String group = '',
    bool favorite = false,
    OtpType type = OtpType.totp,
    bool team = false,
  }) => (
    OtpEntry(
      issuer: issuer,
      account: account,
      secret: _secret(r),
      type: type,
      group: group,
      favorite: favorite,
    ),
    team: team,
  );
  return [
    e('GitHub', 'alex@example.org', group: 'Arbeit', favorite: true),
    e('Proton', 'alex@example.org', group: 'Privat', favorite: true),
    e('Nextcloud', 'alex', group: 'Privat', favorite: true),
    e('Cloudflare', 'admin@example.org', group: 'Arbeit', team: true),
    e('Hetzner', 'K0815', group: 'Arbeit', team: true),
    e('Mastodon', '@alex@example.social', group: 'Privat'),
    e('PayPal', 'alex@example.org', group: 'Privat'),
    e('Discord', 'alex#4711', group: 'Privat'),
    e('Dropbox', 'alex@example.org', group: 'Privat'),
    e('Tailscale', 'admin@example.org', group: 'Arbeit', team: true),
    e('Home Assistant', 'alex', group: 'Privat'),
    e('Steam', 'alex_spielt', group: 'Privat', type: OtpType.steam),
  ];
}

Future<void> _settle(WidgetTester tester, [int frames = 15]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('README screenshots', skip: _shots.isEmpty, (tester) async {
    expect(AppEnv.name, 'test', reason: 'nur mit SIXORA_ENV=test');
    await tester.runAsync(ServiceIcons.load);
    final controller = await AppController.create();
    if (controller.cached != null) await controller.logout(notice: '');
    controller.notice = null;

    final r = Random(6);
    await controller.register(
      server: Uri.parse(_server),
      serverName: 'Sixora',
      username: 'alex',
      password: 'demo-passwort-${r.nextInt(1 << 30)}',
    );
    await controller.enter();
    // The vaults arrive with the first sync, which [enter] starts.
    for (var i = 0; i < 100 && controller.writableVaults.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(controller.syncError, isNull);
    final own = controller.writableVaults.first.id;
    await controller.createVault('Team');
    final team = controller.writableVaults.firstWhere((v) => v.id != own).id;
    for (final (entry, team: inTeam) in _demo(r)) {
      await controller.saveEntry(entry, vaultId: inTeam ? team : own);
    }

    final boundary = GlobalKey();
    Future<void> shot(String name) async {
      // Early in the 30-second period: full rings, no red codes.
      while ((DateTime.now().second % 30) > 12) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await _settle(tester);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final png = await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      final text = base64.encode(png!);
      for (var i = 0; i < text.length; i += 800) {
        // ignore: avoid_print
        print('SHOT $name ${text.substring(i, min(i + 800, text.length))}');
      }
    }

    Future<void> size(double width, double height) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = Size(width * 2, height * 2);
      await _settle(tester);
    }

    Future<void> theme(String mode) async {
      controller.settings.themeMode = mode;
      await controller.saveSettings();
      await _settle(tester);
    }

    // A test window in the background must not lock the app, and the
    // offer to unlock with Touch ID would cover the list.
    controller.settings.autoLock = AutoLock.never;
    controller.offerBiometrics = false;
    await controller.saveSettings();

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: SixoraApp(controller: controller),
      ),
    );
    await _settle(tester, 30);

    await size(1000, 720);
    await theme('light');
    await shot('desktop');

    await size(400, 860);
    await theme('dark');
    await shot('mobile-dark');

    expect(controller.phase, Phase.unlocked);
    final nav = Navigator.of(tester.element(find.byType(HomeScreen)));
    final github = controller.items.firstWhere(
      (i) => i.entry.issuer == 'GitHub',
    );
    nav.push(
      MaterialPageRoute<void>(builder: (_) => EntryEditor(item: github)),
    );
    await shot('editor');
    nav.pop();
    await _settle(tester);

    await controller.logout(notice: '');
    tester.view.reset();
  });
}
