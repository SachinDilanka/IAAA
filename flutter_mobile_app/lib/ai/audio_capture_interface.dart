abstract class AudioCaptureInterface {
  void startCapture({
    required Function(List<double> frame, double volume, int peakFreq) onAudioFrame,
    required Function(String detectedClass, double confidence, String source) onAudioEvent,
    required Function(String transcript) onSpeechTranscript,
  });

  void stopCapture();

  Future<bool> connectBleWatch();

  void sendWatchVibration(String priority, {String? title, String? sinhala, String? soundClass});

  void playSample(String soundName);

  Map<String, dynamic> pollLatestState();

  void setSpeechLanguage(String langCode);

  void setSensitivity(String level);
}
