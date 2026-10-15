import 'package:just_audio/just_audio.dart';

class LetterAudio {
  LetterAudio._();

  static final LetterAudio instance = LetterAudio._();

  final AudioPlayer _player = AudioPlayer();

  static const Map<String, String> _clips = {
    'අ': 'assets/audio/clip1.mp3',
    'ආ': 'assets/audio/clip2.mp3',
    'ඇ': 'assets/audio/clip3.mp3',
    'ඈ': 'assets/audio/clip4.mp3',
  };

  bool hasAudio(String letter) => _clips.containsKey(letter);

  Future<void> play(String letter) async {
    final path = _clips[letter];
    if (path == null) return;
    await _player.stop();
    await _player.setAsset(path);
    await _player.play();
  }

  Future<void> stop() => _player.stop();
}
