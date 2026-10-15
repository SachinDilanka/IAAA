import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sinhala_speech_therapy/core/models/exercise.dart';
import 'package:sinhala_speech_therapy/core/services/api_service.dart';
import 'package:sinhala_speech_therapy/core/services/speech_service.dart';
import 'package:sinhala_speech_therapy/features/app/app_controller.dart';
import 'package:sinhala_speech_therapy/features/practice/letter_practice_screen.dart';
import 'package:sinhala_speech_therapy/l10n/generated/app_localizations.dart';

class _MockApiService extends Mock implements ApiService {}

class _MockSpeechService extends Mock implements SpeechService {}

void main() {
  testWidgets('letter practice includes camera and speech tools', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'language': 'en'});
    final preferences = await SharedPreferences.getInstance();
    final api = _MockApiService();
    final speech = _MockSpeechService();
    when(() => speech.stopListening()).thenAnswer((_) async {});
    final controller = AppController(
      api: api,
      speech: speech,
      preferences: preferences,
    )..isLoading = false;
    controller.letters = const [
      Exercise(
        id: 1,
        category: ExerciseCategory.letter,
        sinhalaText: 'අ',
        steps: ['අ'],
        sinhalaInstruction: 'අ කියන්න',
        emoji: '🔤',
        difficulty: 1,
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const LetterPracticeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Letter practice'), findsWidgets);
    expect(find.text('Camera mirror'), findsOneWidget);
    expect(find.text('Start camera'), findsOneWidget);
    expect(find.text('Live speech recognition'), findsOneWidget);
    expect(find.text('Start listening'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
