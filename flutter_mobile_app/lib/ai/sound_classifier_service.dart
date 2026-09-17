import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/detection_event.dart';
import '../services/priority_engine.dart';
import '../alerts/vibration_manager.dart';
import '../wearable/smartwatch_service.dart';
import '../storage/history_database.dart';
import 'audio_capture_interface.dart';
import 'audio_capture_bridge.dart';

class SoundClassifierService extends ChangeNotifier {
  static final SoundClassifierService _instance = SoundClassifierService._internal();
  factory SoundClassifierService() => _instance;
  SoundClassifierService._internal() {
    _bridge = getAudioCaptureBridge();
  }

  late final AudioCaptureInterface _bridge;
  final PriorityEngine _priorityEngine = PriorityEngine();
  final VibrationManager _vibrationManager = VibrationManager();
  final SmartwatchService _smartwatchService = SmartwatchService();
  final HistoryDatabase _historyDatabase = HistoryDatabase();

  bool _isListening = false;
  bool _autoDetectWhileListening = false;
  DetectionEvent? _lastEvent;
  DetectionEvent? _activeAlert;
  Timer? _activeAlertDismissTimer;
  Timer? _visualizerTicker;

  List<double> _liveSpectrogramFrame = List.generate(40, (i) => 0.16);
  double _currentRmsVolume = 0.12;
  int _currentPitchHz = 220;
  String _liveSpeechTranscript = "🎤 AI Audio & Voice Monitor Standby (Tap 'Start Mic' or anywhere to activate)...";
  String _speechLanguage = 'si-LK';
  String _sensitivity = 'high';

  bool get isListening => _isListening;
  bool get autoDetectWhileListening => _autoDetectWhileListening;
  DetectionEvent? get lastEvent => _lastEvent;
  DetectionEvent? get activeAlert => _activeAlert;
  List<double> get liveSpectrogramFrame => _liveSpectrogramFrame;
  double get currentRmsVolume => _currentRmsVolume;
  int get currentPitchHz => _currentPitchHz;
  String get liveSpeechTranscript => _liveSpeechTranscript;
  String get speechLanguage => _speechLanguage;
  String get sensitivity => _sensitivity;
  String _monitorMode = 'voice';
  String get monitorMode => _monitorMode;

  void setMonitorMode(String mode) {
    _monitorMode = mode;
    _bridge.setMonitorMode(mode);
    notifyListeners();
  }

  void setSensitivity(String level) {
    _sensitivity = level;
    _bridge.setSensitivity(level);
    notifyListeners();
  }

  void setSpeechLanguage(String lang) {
    _speechLanguage = lang;
    _bridge.setSpeechLanguage(lang);
    notifyListeners();
  }

  void setAutoDetectWhileListening(bool enabled) {
    _autoDetectWhileListening = enabled;
    notifyListeners();
  }

  void playSoundSample(String soundName) {
    _bridge.playSample(soundName);
  }

  void startListening() {
    if (_isListening) return;
    _isListening = true;
    _liveSpeechTranscript = "🎤 Live Mic Active: Listening for Sinhala Voice & Sounds...";
    notifyListeners();

    // 1. High-frequency (30 FPS) synchronous JS state polling loop
    _visualizerTicker?.cancel();
    _visualizerTicker = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!_isListening) return;

      final state = _bridge.pollLatestState();
      if (state.isNotEmpty) {
        bool changed = false;

        final double? vol = state['volume'] as double?;
        if (vol != null && (vol - _currentRmsVolume).abs() > 0.003) {
          _currentRmsVolume = vol;
          changed = true;
        }

        final int? pitch = state['pitch'] as int?;
        if (pitch != null && pitch != _currentPitchHz) {
          _currentPitchHz = pitch;
          changed = true;
        }

        final String? transcript = state['transcript'] as String?;
        if (transcript != null && transcript.isNotEmpty && transcript != _liveSpeechTranscript) {
          _liveSpeechTranscript = transcript;
          changed = true;
        }

        final List<double>? frame = state['frame'] as List<double>?;
        if (frame != null && frame.length == 40) {
          _liveSpectrogramFrame = frame;
          changed = true;
        }



        if (changed) {
          notifyListeners();
        }
      }
    });

    // 2. Real-Time High-Gain Live Microphone & Dual STT Classifier Bridge
    _bridge.startCapture(
      onAudioFrame: (frame, volume, peakFreq) {
        if (!_isListening) return;
        _liveSpectrogramFrame = frame;
        _currentRmsVolume = volume;
        _currentPitchHz = peakFreq;
        notifyListeners();
      },
      onAudioEvent: (detectedClass, confidence, source) {
        if (!_isListening) return;
        simulateDetection(detectedClass, confidence: confidence, source: source, isLive: true);
      },
      onSpeechTranscript: (transcript) {
        if (!_isListening) return;
        _liveSpeechTranscript = transcript;
        notifyListeners();
      },
    );
  }

  void stopListening() {
    _isListening = false;
    _visualizerTicker?.cancel();
    _visualizerTicker = null;
    _bridge.stopCapture();
    _liveSpectrogramFrame = List.generate(40, (i) => 0.02);
    _currentRmsVolume = 0.0;
    _currentPitchHz = 0;
    _liveSpeechTranscript = "Microphone monitoring paused.";
    notifyListeners();
  }

  void dismissActiveAlert() {
    _activeAlertDismissTimer?.cancel();
    _activeAlert = null;
    notifyListeners();
  }

  /// Trigger exact sound classification event from Live Mic, Voice Speech, or Test Button
  Future<void> simulateDetection(
    String rawClass, {
    double confidence = 0.96,
    String source = "Offline Acoustic Detection",
    bool isLive = false,
  }) async {
    final event = _priorityEngine.processPrediction(
      rawClass: rawClass,
      confidence: confidence,
      minThreshold: 0.25, // Validated sound threshold for real-world acoustics
      bypassCooldown: !isLive, // Only bypass cooldown for manual test button presses
    );

    if (event == null) return;

    _lastEvent = event;
    _activeAlert = event;
    _liveSpeechTranscript = "🚨 DETECTED: ${event.titleEnglish} (${event.titleSinhala})";
    notifyListeners();

    // Play synthesized emergency audio tone or voice
    if (!isLive) {
      _bridge.playSample(rawClass);
    }

    // Phone Tactile Vibration (Differentiated per sound class)
    await _vibrationManager.triggerHapticPattern(event.priority, rawClass: rawClass);

    // Send Distinct Vibration & Warning Message to Yesido IO39 Smartwatch
    _bridge.sendWatchVibration(
      event.priority.name,
      title: '🚨 ${event.titleEnglish}',
      sinhala: event.titleSinhala,
      soundClass: rawClass,
    );
    await _smartwatchService.sendWatchAlert(event);

    // Save Event to History Log
    await _historyDatabase.saveEvent(event);

    // Auto-clear active alert highlight after 7 seconds
    _activeAlertDismissTimer?.cancel();
    _activeAlertDismissTimer = Timer(const Duration(milliseconds: 7000), () {
      if (_activeAlert?.id == event.id) {
        _activeAlert = null;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _visualizerTicker?.cancel();
    _bridge.stopCapture();
    _activeAlertDismissTimer?.cancel();
    super.dispose();
  }
}
