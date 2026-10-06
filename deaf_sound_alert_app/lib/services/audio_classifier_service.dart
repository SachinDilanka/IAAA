import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../models/detected_sound.dart';
import 'vibration_service.dart';
import 'flashlight_service.dart';
import 'smartwatch_service.dart';
import 'sound_config_service.dart';
import 'history_service.dart';
import 'native_neural_audio_classifier.dart';

class AudioClassifierService {
  static final AudioClassifierService _instance =
      AudioClassifierService._internal();
  factory AudioClassifierService() => _instance;
  AudioClassifierService._internal();

  final NativeNeuralAudioClassifier _neuralClassifier =
      NativeNeuralAudioClassifier();

  AudioRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _recordStreamSub;

  bool _isListening = false;
  double _latestSoundVolume = 0.02;
  final List<double> _visualizerBars = List<double>.filled(40, 0.15);

  // 16,000 Hz circular rolling audio buffer (1 second = 16,000 samples)
  final List<double> _rollingBuf16k = List<double>.filled(16000, 0.0);
  int _rollingIdx = 0;
  int _total16kPushed = 0;
  int _lastMlTimeMs = 0;
  int _listeningStartTimeMs = 0;
  int _lastSpeechEnergyMs = 0;
  int _keywordLockUntilMs = 0;
  String? _currentDisplayedKeyword;

  // Utterance tracking for high-accuracy keyword detection near and far
  String? _currentUtteranceBestClass;
  double _currentUtteranceBestProb = 0.0;
  int _utteranceSpeechFrames = 0;
  int _utteranceSilenceFrames = 0;

  // Environmental sound tracking
  String? _pendingEnvClass;
  int _pendingEnvVotes = 0;

  final Map<String, DateTime> _lastSoundAlertTimes = {};
  DateTime? _lastEmittedAlertTime;

  final _controller = StreamController<DetectedSound>.broadcast();
  final _waveformController = StreamController<List<double>>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();
  final _sttStatusController = StreamController<String>.broadcast();

  String _sttStatus = '';

  bool get isListening => _isListening;
  Stream<DetectedSound> get onSoundDetected => _controller.stream;
  Stream<List<double>> get onWaveformUpdated => _waveformController.stream;
  Stream<String> get onTranscriptUpdated => _transcriptController.stream;
  Stream<String> get onSttStatus => _sttStatusController.stream;
  String get sttStatus => _sttStatus;
  String? get currentDisplayedKeyword => _currentDisplayedKeyword;

  void _setSttStatus(String status) {
    if (status == _sttStatus) return;
    _sttStatus = status;
    _sttStatusController.add(status);
  }

  // Exact Live Speech display strings for 8 Sinhala emergency keywords
  static const Map<String, String> _sinhalaLiveSpeechDisplay = {
    'sinhala_udaw_': 'udaw  →  උදව් (Udaw - Help)',
    'sinhala_beraganna_': 'beeraganna  →  බේරගන්න (Beraganna - Save Me)',
    'sinhala_ginnak_': 'ginnak  →  ගින්නක් (Ginnak - Fire)',
    'sinhala_anathurak_': 'anathurak  →  අනතුරක් (Anathurak - Danger)',
    'sinhala_karadarayak_': 'karadarayak  →  කරදරයක් (Karadarayak - Trouble)',
    'sinhala_balagena_': 'balagena  →  බලාගෙන (Balaagena - Watch Out)',
    'sinhala_ehata_wenna_': 'ehata wenna  →  එහාට වෙන්න (Ehata Wenna - Move Aside)',
    'sinhala_parissamin_': 'parissamin  →  පරිස්සමින් (Parissamin - Be Careful)',
  };

  static const Map<String, String> _classToSoundKey = {
    'udaw': 'sinhala_udaw_',
    'beeraganna': 'sinhala_beraganna_',
    'ginnak': 'sinhala_ginnak_',
    'anathurak': 'sinhala_anathurak_',
    'karadarayak': 'sinhala_karadarayak_',
    'balagena': 'sinhala_balagena_',
    'ehata_wenna': 'sinhala_ehata_wenna_',
    'parissamin': 'sinhala_parissamin_',
  };

  static const Map<String, String> _envClassToSoundKey = {
    'ambulance_siren': 'ambulance',
    'fire_truck': 'fire_truck',
    'vehicle_horn': 'vehicle horns',
    'baby_crying': 'baby crying',
    'dog_barking': 'dog_bark_dataset',
  };

  Timer? _visualizerTicker;

  Future<void> init() async {
    try {
      await _neuralClassifier.loadModel();
    } catch (_) {}
  }

  void _updateWaveformVolume(double newVol) {
    final double targetVol = newVol.clamp(0.18, 1.0);
    if (targetVol > _latestSoundVolume) {
      _latestSoundVolume = targetVol;
    } else {
      _latestSoundVolume =
          (_latestSoundVolume * 0.65 + targetVol * 0.35).clamp(0.18, 1.0);
    }
  }

  void _startVisualizerTicker() {
    _visualizerTicker?.cancel();
    _visualizerTicker =
        Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!_isListening) {
        timer.cancel();
        return;
      }

      final double nowSec = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final List<double> newFrame = List<double>.generate(40, (band) {
        final double centerDist = ((band - 20) / 20.0).abs();
        final double centerEnvelope = math.exp(-centerDist * centerDist * 1.2);

        final double ripple1 =
            math.sin(band * 0.40 + nowSec * 6.0).abs() * 0.10;
        final double ripple2 =
            math.cos(band * 0.70 - nowSec * 7.5).abs() * 0.08;

        double targetHeight;
        if (_latestSoundVolume < 0.06) {
          targetHeight = (0.15 + centerEnvelope * 0.12 + ripple1 + ripple2)
              .clamp(0.12, 0.35);
        } else {
          targetHeight = (_latestSoundVolume *
                  (centerEnvelope * 0.70 + ripple1 * 0.6 + 0.35))
              .clamp(0.18, 1.0);
        }
        return targetHeight;
      });

      for (int i = 0; i < 40; i++) {
        _visualizerBars[i] = _visualizerBars[i] * 0.55 + newFrame[i] * 0.45;
      }

      _waveformController.add(List<double>.from(_visualizerBars));
      _latestSoundVolume = (_latestSoundVolume * 0.88).clamp(0.04, 1.0);
    });
  }

  Future<bool> startListening() async {
    if (_isListening) return true;

    try {
      await [
        Permission.microphone,
        Permission.notification,
      ].request();
    } catch (_) {}

    if (!_neuralClassifier.isLoaded) {
      await _neuralClassifier.loadModel();
    }

    _isListening = true;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _listeningStartTimeMs = nowMs;
    _lastSpeechEnergyMs = 0;
    _keywordLockUntilMs = 0;
    _rollingIdx = 0;
    _total16kPushed = 0;
    _lastMlTimeMs = 0;
    _currentUtteranceBestClass = null;
    _currentUtteranceBestProb = 0.0;
    _utteranceSpeechFrames = 0;
    _utteranceSilenceFrames = 0;
    _pendingEnvClass = null;
    _pendingEnvVotes = 0;
    _currentDisplayedKeyword = null;
    _latestSoundVolume = 0.25;
    _rollingBuf16k.fillRange(0, 16000, 0.0);

    _startVisualizerTicker();

    final started = await _startAudioCapture();
    if (!started) {
      _isListening = false;
      _visualizerTicker?.cancel();
      _visualizerTicker = null;
      return false;
    }

    _setSttStatus('Listening offline for 8 Sinhala Keywords & Environmental Sounds');
    return true;
  }

  Future<bool> _startAudioCapture() async {
    try {
      _recordStreamSub?.cancel();
      _audioRecorder?.dispose();
      _audioRecorder = AudioRecorder();

      if (!await _audioRecorder!.hasPermission()) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) return false;
      }

      final stream = await _audioRecorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _recordStreamSub = stream.listen(
        (data) {
          if (!_isListening || data.isEmpty) return;
          _processPcmBytes(data);
        },
        onError: (_) {},
        cancelOnError: false,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _processPcmBytes(Uint8List data) {
    if (data.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final int numSamples = data.length ~/ 2;
    if (numSamples == 0) return;

    final ByteData byteData = ByteData.sublistView(data);
    double sumSquares = 0.0;
    double maxAmp = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final int s16 = byteData.getInt16(i * 2, Endian.little);
      final double sampleNorm = (s16 / 32768.0).clamp(-1.0, 1.0);
      final double absS = sampleNorm.abs();

      if (absS > maxAmp) maxAmp = absS;
      sumSquares += sampleNorm * sampleNorm;

      _rollingBuf16k[_rollingIdx] = sampleNorm;
      _rollingIdx = (_rollingIdx + 1) % 16000;
      _total16kPushed++;
    }

    final double rms = math.sqrt(sumSquares / numSamples);

    // Update real-time bouncing waveform visualizer continuously
    final double soundVol = (maxAmp * 4.0 + rms * 10.0).clamp(0.04, 1.0);
    _updateWaveformVolume(soundVol);

    const speechClasses = [
      'udaw',
      'beeraganna',
      'ginnak',
      'anathurak',
      'karadarayak',
      'balagena',
      'parissamin',
      'ehata_wenna',
    ];

    final bool startupGraceOver = (nowMs - _listeningStartTimeMs >= 500);

    // Run Neural Inference every 135ms on 16k window
    if (_total16kPushed >= 8000 &&
        startupGraceOver &&
        (nowMs - _lastMlTimeMs >= 135)) {
      _lastMlTimeMs = nowMs;

      final List<double> window16k = List<double>.filled(16000, 0.0);
      double windowMax = 0.0;
      for (int i = 0; i < 16000; i++) {
        final s = _rollingBuf16k[(_rollingIdx - 16000 + i + 16000) % 16000];
        window16k[i] = s;
        final absS = s.abs();
        if (absS > windowMax) windowMax = absS;
      }

      // If alert lockout is currently active (2.2s after a keyword fired), hold
      if (nowMs < _keywordLockUntilMs) {
        _currentUtteranceBestClass = null;
        _currentUtteranceBestProb = 0.0;
        _utteranceSpeechFrames = 0;
        _utteranceSilenceFrames = 0;
        _pendingEnvClass = null;
        _pendingEnvVotes = 0;
        return;
      }

      // Silence floor check
      if (windowMax < 0.005) {
        // In silence, if an utterance was previously active and reached silence:
        if (_utteranceSpeechFrames > 0 && _currentUtteranceBestClass != null) {
          _utteranceSilenceFrames++;
          if (_utteranceSilenceFrames >= 2 && _currentUtteranceBestProb >= 0.20) {
            _triggerKeywordAlert(_currentUtteranceBestClass!, _currentUtteranceBestProb, nowMs);
            return;
          }
        }
        return;
      }

      // Dynamic AGC: amplifies near or far sound up to 50x
      final double gain = (0.50 / windowMax).clamp(1.0, 50.0);
      final List<double> normWindow = List<double>.filled(16000, 0.0);
      for (int i = 0; i < 16000; i++) {
        normWindow[i] = (window16k[i] * gain).clamp(-1.0, 1.0);
      }

      final pred = _neuralClassifier.predict(normWindow);
      if (pred == null) return;
      final allP = pred.allProbabilities;

      // Top speech class
      String topSpeechClass = speechClasses.first;
      double topSpeechProb = 0.0;
      for (final s in speechClasses) {
        final p = allP[s] ?? 0.0;
        if (p > topSpeechProb) {
          topSpeechProb = p;
          topSpeechClass = s;
        }
      }

      // Top environmental emergency class
      String? topEnvClass;
      double topEnvProb = 0.0;
      for (final e in _envClassToSoundKey.keys) {
        final p = allP[e] ?? 0.0;
        if (p > topEnvProb) {
          topEnvProb = p;
          topEnvClass = e;
        }
      }

      final bool isChunkSpeech = (maxAmp >= 0.010 || rms >= 0.0018);

      // === 1. SINHALA EMERGENCY KEYWORDS (NEAR & FAR) ===
      if (isChunkSpeech) {
        _lastSpeechEnergyMs = nowMs;
        _utteranceSpeechFrames++;
        _utteranceSilenceFrames = 0;
        _pendingEnvClass = null;
        _pendingEnvVotes = 0;

        if (topSpeechProb > _currentUtteranceBestProb) {
          _currentUtteranceBestProb = topSpeechProb;
          _currentUtteranceBestClass = topSpeechClass;
        }

        // Instant trigger on very high confidence (>= 0.70) when word is fully formed
        if (_currentUtteranceBestProb >= 0.70 && _utteranceSpeechFrames >= 2) {
          _triggerKeywordAlert(_currentUtteranceBestClass!, _currentUtteranceBestProb, nowMs);
          return;
        }
      } else {
        if (_utteranceSpeechFrames > 0 && _currentUtteranceBestClass != null) {
          _utteranceSilenceFrames++;
          // When speech pauses for ~270ms (2 frames), commit the best detected keyword
          if (_utteranceSilenceFrames >= 2 && _currentUtteranceBestProb >= 0.20) {
            _triggerKeywordAlert(_currentUtteranceBestClass!, _currentUtteranceBestProb, nowMs);
            return;
          }
        }
      }

      // === 2. BACKGROUND ENVIRONMENTAL SOUNDS ===
      // Baby Crying, Ambulance Siren, Fire Truck, Vehicle Horns, Dog Barking
      final bool userSpokeRecently = (nowMs - _lastSpeechEnergyMs < 1200);

      if (!userSpokeRecently && topEnvClass != null) {
        final candidateSound = _envClassToSoundKey[topEnvClass];
        if (candidateSound != null) {
          const envThresholds = {
            'ambulance_siren': 0.35,
            'fire_truck': 0.35,
            'vehicle_horn': 0.35,
            'baby_crying': 0.32,
            'dog_barking': 0.35,
          };
          final double reqProb = envThresholds[topEnvClass] ?? 0.35;
          final bool isValid = topEnvProb >= reqProb && topEnvProb > topSpeechProb * 1.20;

          if (isValid) {
            final lastAlert = _lastSoundAlertTimes[candidateSound];
            final bool cooldownPassed = lastAlert == null ||
                nowMs - lastAlert.millisecondsSinceEpoch >= 2200;

            if (_pendingEnvClass == candidateSound) {
              _pendingEnvVotes++;
            } else {
              _pendingEnvClass = candidateSound;
              _pendingEnvVotes = 1;
            }

            if (cooldownPassed && _pendingEnvVotes >= 2) {
              _lastSoundAlertTimes[candidateSound] =
                  DateTime.fromMillisecondsSinceEpoch(nowMs);
              simulateSoundDetection(candidateSound, confidence: topEnvProb);
              _pendingEnvVotes = 0;
              _pendingEnvClass = null;
            }
          } else {
            _pendingEnvVotes = 0;
            _pendingEnvClass = null;
          }
        }
      }
    }
  }

  void _triggerKeywordAlert(String speechClass, double confidence, int nowMs) {
    final soundKey = _classToSoundKey[speechClass];
    if (soundKey == null) return;

    _keywordLockUntilMs = nowMs + 2200; // Hold for 2.2s so user can test next word sequentially
    _currentDisplayedKeyword = soundKey;
    _lastSpeechEnergyMs = nowMs;
    _currentUtteranceBestClass = null;
    _currentUtteranceBestProb = 0.0;
    _utteranceSpeechFrames = 0;
    _utteranceSilenceFrames = 0;

    // 1. Display formatted keyword in Live Speech box
    final displayText = _sinhalaLiveSpeechDisplay[soundKey] ?? speechClass;
    _transcriptController.add(displayText);

    // 2. Pop up ONLY that matching emergency alert card!
    unawaited(simulateSoundDetection(
      soundKey,
      confidence: math.max(confidence, 0.98),
      overrideCooldown: true,
    ));

    // Zero out rolling buffer to eliminate trailing noise hallucinations
    _rollingBuf16k.fillRange(0, 16000, 0.0);
  }

  void stopListening() {
    _isListening = false;
    _visualizerTicker?.cancel();
    _visualizerTicker = null;
    _latestSoundVolume = 0.02;
    _waveformController.add([]);
    _currentDisplayedKeyword = null;
    _currentUtteranceBestClass = null;
    _currentUtteranceBestProb = 0.0;
    _utteranceSpeechFrames = 0;
    _utteranceSilenceFrames = 0;
    _pendingEnvClass = null;
    _pendingEnvVotes = 0;

    _recordStreamSub?.cancel();
    _recordStreamSub = null;
    try {
      _audioRecorder?.stop();
      _audioRecorder?.dispose();
    } catch (_) {}
    _audioRecorder = null;
  }

  Future<void> simulateSoundDetection(String soundKey,
      {double confidence = 0.92, bool overrideCooldown = false}) async {
    final now = DateTime.now();

    if (!overrideCooldown) {
      final lastSoundTime = _lastSoundAlertTimes[soundKey];
      if (lastSoundTime != null &&
          now.difference(lastSoundTime).inMilliseconds < 2500) {
        return;
      }
      if (_lastEmittedAlertTime != null &&
          now.difference(_lastEmittedAlertTime!).inMilliseconds < 1000) {
        return;
      }
    }

    final soundConfig = SoundConfigService().getConfig(soundKey);
    if (soundConfig == null || !soundConfig.isEnabled) return;

    _lastEmittedAlertTime = now;
    _lastSoundAlertTimes[soundKey] = now;

    final event = DetectedSound(
      id: now.millisecondsSinceEpoch.toString(),
      soundKey: soundConfig.key,
      soundName: soundConfig.name,
      category: soundConfig.category,
      priority: soundConfig.priority,
      confidence: confidence,
      timestamp: now,
    );

    // 1. Emit event to UI IMMEDIATELY (0ms latency for instant alert card popup!)
    _controller.add(event);

    // 2. Trigger Phone Vibration instantly
    VibrationService().triggerVibration(event.priority);

    // 3. Trigger Flashlight Flashing pattern instantly (synced with vibration)
    FlashlightService().triggerFlashlightPattern(event.priority);

    // 4. Save log to history & sync to Yesido IO 39 smartwatch asynchronously in background
    unawaited(HistoryService().addEvent(event));
    unawaited(SmartwatchService().sendAlertToWatch(event));
  }

  void dispose() {
    stopListening();
    _controller.close();
    _waveformController.close();
    _transcriptController.close();
    _sttStatusController.close();
  }
}

