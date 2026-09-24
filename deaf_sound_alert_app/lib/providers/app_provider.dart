import 'dart:async';
import 'package:flutter/material.dart';
import '../models/detected_sound.dart';
import '../models/sound_config.dart';
import '../services/audio_classifier_service.dart';
import '../services/sound_config_service.dart';
import '../services/history_service.dart';
import '../services/smartwatch_service.dart';
import '../services/vibration_service.dart';

class AppProvider with ChangeNotifier {
  bool _isLoading = true;
  bool _isListening = false;
  DetectedSound? _lastDetectedSound;
  List<double> _currentWaveform = [];
  String _currentTranscript = "";
  StreamSubscription? _soundSub;
  StreamSubscription? _waveSub;
  StreamSubscription? _transcriptSub;

  bool get isLoading => _isLoading;
  bool get isListening => _isListening;
  DetectedSound? get lastDetectedSound => _lastDetectedSound;
  List<double> get currentWaveform => _currentWaveform;
  String get currentTranscript => _currentTranscript;
  List<SoundConfig> get soundConfigs => SoundConfigService().configs;
  List<DetectedSound> get history => HistoryService().history;
  bool get isSmartwatchConnected => SmartwatchService().isConnected;
  String get connectedWatchName => SmartwatchService().connectedDeviceName;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await VibrationService().init();
    await SmartwatchService().init();
    await SoundConfigService().init();
    await HistoryService().init();
    await AudioClassifierService().init();

    _soundSub = AudioClassifierService().onSoundDetected.listen((sound) {
      _lastDetectedSound = sound;
      notifyListeners();
    });

    _waveSub = AudioClassifierService().onWaveformUpdated.listen((waveform) {
      _currentWaveform = waveform;
      notifyListeners();
    });

    _transcriptSub = AudioClassifierService().onTranscriptUpdated.listen((transcript) {
      _currentTranscript = transcript;
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleListening() async {
    if (_isListening) {
      AudioClassifierService().stopListening();
      _isListening = false;
      _currentTranscript = "";
    } else {
      await AudioClassifierService().startListening();
      _isListening = true;
    }
    notifyListeners();
  }

  void dismissLastSound() {
    _lastDetectedSound = null;
    notifyListeners();
  }

  Future<void> simulateSound(String soundKey) async {
    await AudioClassifierService().simulateSoundDetection(soundKey);
  }

  Future<void> updateSoundPriority(String key, PriorityLevel priority) async {
    await SoundConfigService().updatePriority(key, priority);
    notifyListeners();
  }

  Future<void> toggleSoundEnabled(String key, bool enabled) async {
    await SoundConfigService().toggleEnabled(key, enabled);
    notifyListeners();
  }

  Future<void> removeHistoryEvent(String id) async {
    await HistoryService().removeEvent(id);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await HistoryService().clearHistory();
    notifyListeners();
  }

  Future<bool> pairSmartwatch() async {
    final devices = await SmartwatchService().scanDevices();
    if (devices.isNotEmpty) {
      await SmartwatchService().connectToWatch(devices.first);
    } else {
      await SmartwatchService().connectToWatch(null as dynamic);
    }
    notifyListeners();
    return true;
  }

  Future<void> disconnectSmartwatch() async {
    await SmartwatchService().disconnectWatch();
    notifyListeners();
  }

  @override
  void dispose() {
    _soundSub?.cancel();
    _waveSub?.cancel();
    _transcriptSub?.cancel();
    super.dispose();
  }
}
