import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _recognizer = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Future<Map<String, String>>? _audioManifest;

  bool get isListening => _recognizer.isListening;

  Future<bool> speakSinhala(String text) async {
    final target = text.trim();
    if (target.isEmpty) return false;

    await _tts.stop();
    await _audioPlayer.stop();

    if (await _playBundledAudio(target)) return true;

    try {
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.08);
      await _tts.awaitSpeakCompletion(true);

      const localeCandidates = ['si-LK', 'si_LK', 'si'];
      String? selectedLocale;
      for (final locale in localeCandidates) {
        final availability = await _tts.isLanguageAvailable(locale);
        if (availability == true || availability == 1) {
          selectedLocale = locale;
          break;
        }
      }
      // Some browser engines can speak Sinhala even before reporting the voice
      // in their asynchronous voice list, so make one direct attempt as well.
      selectedLocale ??= 'si-LK';

      final languageResult = await _tts.setLanguage(selectedLocale);
      if (languageResult == false || languageResult == 0) return false;
      final speakResult = await _tts.speak(target);
      return speakResult == null || speakResult == true || speakResult == 1;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _playBundledAudio(String text) async {
    try {
      final manifest = await (_audioManifest ??= _loadAudioManifest());
      final assetPath = manifest[text];
      if (assetPath == null) return false;

      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource(assetPath));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> _loadAudioManifest() async {
    final json = await rootBundle.loadString('assets/audio/si/manifest.json');
    final values = jsonDecode(json) as Map<String, dynamic>;
    return values.map((key, value) => MapEntry(key, value as String));
  }

  Future<bool> startListening(
    void Function(String words, bool isFinal) onResult,
  ) async {
    final available = await _recognizer.initialize();
    if (!available) return false;
    await _recognizer.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'si_LK',
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
    );
    return true;
  }

  Future<void> stopListening() => _recognizer.stop();

  Future<void> dispose() async {
    await _recognizer.stop();
    await _tts.stop();
    await _audioPlayer.dispose();
  }
}
