import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/data/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await AppController.create();
  runApp(SixoraApp(controller: controller));
}
