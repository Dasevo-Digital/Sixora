import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/data/app_controller.dart';
import 'src/data/service_icons.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(
        ['Simple Icons (Dienst-Logos)'],
        '''
Die Logos der Dienste stammen aus Simple Icons (https://simpleicons.org),
veröffentlicht unter CC0 1.0. Einzelne Icons stehen unter eigenen,
freizügigen Lizenzen; sie sind in THIRD_PARTY_NOTICES.md aufgeführt.
Die Marken und Logos gehören ihren jeweiligen Inhabern. Ihre Verwendung
kennzeichnet nur den Dienst und bedeutet keine Verbindung zu Sixora.''',
      ),
    ),
  );
  // Loads in the background; avatars show letters until then.
  ServiceIcons.load();
  final controller = await AppController.create();
  runApp(SixoraApp(controller: controller));
}
