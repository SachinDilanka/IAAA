import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/child_profile.dart';
import '../../core/models/exercise.dart';
import '../../core/models/progress_summary.dart';
import '../../core/services/api_service.dart';
import '../../core/services/speech_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.api,
    required this.speech,
    required this.preferences,
  });

  static const _languageKey = 'language';
  static const childId = 1;

  final ApiService api;
  final SpeechService speech;
  final SharedPreferences preferences;

  Locale _locale = const Locale('si');
  Locale get locale => _locale;
  bool get isSinhala => _locale.languageCode == 'si';

  ChildProfile? child;
  List<Exercise> letters = const [];
  List<Exercise> words = const [];
  ProgressSummary progress = ProgressSummary.empty;
  bool isLoading = true;
  String? loadError;

  Future<void> initialize() async {
    _locale = Locale(preferences.getString(_languageKey) ?? 'si');
    unawaited(reload());
  }

  Future<void> reload() async {
    isLoading = true;
    loadError = null;
    notifyListeners();
    final errors = <Object>[];

    await Future.wait([
      _loadSafely(() async => child = await api.getChild(childId), errors),
      _loadSafely(
        () async => letters = await api.getExercises(ExerciseCategory.letter),
        errors,
      ),
      _loadSafely(
        () async => words = await api.getExercises(ExerciseCategory.word),
        errors,
      ),
      _loadSafely(
        () async => progress = await api.getProgress(childId),
        errors,
      ),
    ]);

    if (errors.isNotEmpty) {
      loadError = errors.map((error) => error.toString()).join('\n');
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadSafely(
    Future<void> Function() operation,
    List<Object> errors,
  ) async {
    try {
      await operation();
    } catch (error) {
      errors.add(error);
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    await preferences.setString(_languageKey, locale.languageCode);
    notifyListeners();
  }

  Future<ChildProfile> updateProfile(String name, int age) async {
    final updated = await api.updateChild(childId, name, age);
    child = updated;
    notifyListeners();
    return updated;
  }

  Future<void> completeExercise(
    Exercise exercise, {
    String emotion = 'happy',
  }) async {
    await api.recordAttempt(
      childId: childId,
      exerciseId: exercise.id,
      emotion: emotion,
    );
    progress = await api.getProgress(childId);
    notifyListeners();
  }

  Future<void> refreshProgress() async {
    progress = await api.getProgress(childId);
    notifyListeners();
  }

  @override
  void dispose() {
    api.dispose();
    speech.dispose();
    super.dispose();
  }
}
