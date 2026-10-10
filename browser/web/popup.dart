import 'dart:async';
import 'dart:js_interop';

import 'package:sixora_browser/src/extension.dart';
import 'package:sixora_browser/src/texts.dart';
import 'package:sixora_browser/src/web/bridge.dart';
import 'package:sixora_browser/src/web/popup_ui.dart';
import 'package:web/web.dart' as web;

void main() {
  final texts = Texts.of(bridge.language());
  runZonedGuarded(
    () async {
      web.document.documentElement?.setAttribute('lang', texts.code);
      final extension = SixoraExtension(
        local: BrowserStore('local'),
        session: BrowserStore('session'),
        device: browserDevice(
          web.window.navigator.userAgent,
          brave: bridge.isBrave(),
        ),
      );
      await PopupUi(
        extension,
        texts,
        inTab: web.window.location.hash == '#setup',
      ).start();
    },
    // Shown instead of an empty popup.
    (error, stack) {
      final box = web.document.createElement('p')
        ..className = 'error crash'
        ..textContent = texts.error(error);
      web.document.getElementById('app')?.appendChild(box);
      web.console.error('$error\n$stack'.toJS);
    },
  );
}
