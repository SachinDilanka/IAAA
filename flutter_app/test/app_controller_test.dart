import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sinhala_speech_therapy/core/models/child_profile.dart';
import 'package:sinhala_speech_therapy/core/models/exercise.dart';
import 'package:sinhala_speech_therapy/core/models/progress_summary.dart';
import 'package:sinhala_speech_therapy/core/services/api_service.dart';
import 'package:sinhala_speech_therapy/core/services/speech_service.dart';
import 'package:sinhala_speech_therapy/features/app/app_controller.dart';

class MockApiService extends Mock implements ApiService {}

class MockSpeechService extends Mock implements SpeechService {}

void main() {
  late MockApiService api;
  late MockSpeechService speech;
  late SharedPreferences preferences;

  setUpAll(() {
    registerFallbackValue(ExerciseCategory.letter);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    preferences = await SharedPreferences.getInstance();
    api = MockApiService();
    speech = MockSpeechService();
    when(() => api.getChild(1)).thenAnswer(
      (_) async => const ChildProfile(
        id: 1,
        name: 'Little Learner',
        age: 5,
        avatarId: 'tikiri',
        currentLevel: 'letters',
      ),
    );
    when(() => api.getExercises(any())).thenAnswer((_) async => <Exercise>[]);
    when(() => api.getProgress(1))
        .thenAnswer((_) async => ProgressSummary.empty);
    when(() => api.dispose()).thenReturn(null);
    when(() => speech.dispose()).thenAnswer((_) async {});
  });

  test('restores and persists the selected language', () async {
    final controller = AppController(
      api: api,
      speech: speech,
      preferences: preferences,
    );
    await controller.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(controller.locale, const Locale('en'));
    await controller.setLocale(const Locale('si'));
    expect(preferences.getString('language'), 'si');
  });

  test(
    'updates the child profile through the real controller workflow',
    () async {
      final controller = AppController(
        api: api,
        speech: speech,
        preferences: preferences,
      );
      const updated = ChildProfile(
        id: 1,
        name: 'Nimali',
        age: 7,
        avatarId: 'tikiri',
        currentLevel: 'letters',
      );
      when(() => api.updateChild(1, 'Nimali', 7))
          .thenAnswer((_) async => updated);

      final result = await controller.updateProfile('Nimali', 7);

      expect(result.name, 'Nimali');
      expect(controller.child, updated);
      verify(() => api.updateChild(1, 'Nimali', 7)).called(1);
    },
  );

  test('records exercise completion and refreshes progress', () async {
    final controller = AppController(
      api: api,
      speech: speech,
      preferences: preferences,
    );
    const exercise = Exercise(
      id: 8,
      category: ExerciseCategory.letter,
      sinhalaText: 'අ',
      steps: ['අ'],
      sinhalaInstruction: 'අ කියන්න',
      emoji: '🔤',
      difficulty: 1,
    );
    const updatedProgress = ProgressSummary(
      completed: 1,
      available: 28,
      percent: 3,
      stars: 3,
      history: [],
    );
    when(() => api.recordAttempt(childId: 1, exerciseId: 8, emotion: 'happy'))
        .thenAnswer((_) async {});
    when(() => api.getProgress(1)).thenAnswer((_) async => updatedProgress);

    await controller.completeExercise(exercise);

    expect(controller.progress.stars, 3);
    verify(() => api.recordAttempt(childId: 1, exerciseId: 8, emotion: 'happy'))
        .called(1);
  });
}
