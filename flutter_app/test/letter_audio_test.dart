import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinhala_speech_therapy/core/services/letter_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the first four Sinhala letters have dedicated audio clips', () {
    expect(LetterAudio.instance.hasAudio('අ'), isTrue);
    expect(LetterAudio.instance.hasAudio('ආ'), isTrue);
    expect(LetterAudio.instance.hasAudio('ඇ'), isTrue);
    expect(LetterAudio.instance.hasAudio('ඈ'), isTrue);
    expect(LetterAudio.instance.hasAudio('ඉ'), isFalse);
  });

  test('all dedicated letter audio assets are bundled', () async {
    for (var index = 1; index <= 4; index++) {
      final data = await rootBundle.load('assets/audio/clip$index.mp3');
      expect(data.lengthInBytes, greaterThan(1000));
    }
  });
}
