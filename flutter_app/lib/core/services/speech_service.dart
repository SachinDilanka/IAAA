import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _recognizer = SpeechToText();
  bool get isListening => _recognizer.isListening;

  Future<bool> speakSinhala(String text) async {
    if (text.trim().isEmpty) return false;
    try {
      await _tts.stop();
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
      final speakResult = await _tts.speak(text);
      return speakResult == null || speakResult == true || speakResult == 1;
    } catch (_) {
      return false;
    }
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
  }
}
