import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services/api_service.dart';
import 'core/services/speech_service.dart';
import 'features/app/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final controller = AppController(
    api: ApiService(),
    speech: SpeechService(),
    preferences: preferences,
  );
  await controller.initialize();

  runApp(
    ChangeNotifierProvider.value(
      value: controller,
      child: const SpeechTherapyApp(),
    ),
  );
}
