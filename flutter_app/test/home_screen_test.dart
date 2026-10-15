import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sinhala_speech_therapy/core/services/api_service.dart';
import 'package:sinhala_speech_therapy/core/services/speech_service.dart';
import 'package:sinhala_speech_therapy/features/app/app_controller.dart';
import 'package:sinhala_speech_therapy/features/home/home_screen.dart';
import 'package:sinhala_speech_therapy/l10n/generated/app_localizations.dart';

class _MockApiService extends Mock implements ApiService {}

class _MockSpeechService extends Mock implements SpeechService {}

void main() {
  testWidgets('home presents the illustrated practice choices in landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'language': 'en'});
    final preferences = await SharedPreferences.getInstance();
    final api = _MockApiService();
    final speech = _MockSpeechService();
    when(() => api.dispose()).thenReturn(null);
    when(() => speech.dispose()).thenAnswer((_) async {});
    final controller = AppController(
      api: api,
      speech: speech,
      preferences: preferences,
    );
    await controller.setLocale(const Locale('en'));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello! Welcome!'), findsOneWidget);
    expect(find.text("Let's start"), findsOneWidget);
    expect(find.text('Letter practice'), findsOneWidget);
    expect(find.text('Word practice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
