import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
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

  static const MethodChannel _speechChannel =
      MethodChannel('com.deafalert.app/speech');
  static const EventChannel _speechEvents =
      EventChannel('com.deafalert.app/speech/events');
  StreamSubscription? _speechSubscription;

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
  int _lastSpeechTimeMs = 0;
  int _keywordLockUntilMs = 0;
  String? _currentDisplayedKeyword;

  final Map<String, DateTime> _lastSoundAlertTimes = {};
  final Map<String, DateTime> _lastKeywordTriggerTimes = {};
  DateTime? _lastEmittedAlertTime;
  String? _pendingEnvironmentSound;
  int _pendingEnvironmentVotes = 0;

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

  static const Map<String, List<String>> _sinhalaKeywords = {
    'sinhala_udaw_': [
      'udaw', 'udau', 'udav', 'udaaw', 'udaav', 'help', 'sos', 'emergency',
      'wood owl', 'you dow', 'ooh dow', 'who dow', 'you down', 'u down', 'u dow',
      'dow', 'dao', 'උදව්', 'උදවු', 'උදව්ව', 'උදව් කරන්න', 'උදව්වක්'
    ],
    'sinhala_karadarayak_': [
      'karadarayak', 'karadara', 'karadarai', 'karadarak', 'karadare',
      'trouble', 'problem', 'kara da rai', 'kara da rak', 'car direct',
      'care direct', 'cardiac', 'කරදරයක්', 'කරදර', 'කරදරයි', 'කරදරේ'
    ],
    'sinhala_anathurak_': [
      'anathurak', 'anatura', 'anathura', 'anathurai', 'anaturak',
      'danger', 'warning', 'accident', 'another act', 'another track',
      'අනතුරක්', 'අනතුර', 'අනතුරයි', 'අනතුරු'
    ],
    'sinhala_beraganna_': [
      'beraganna', 'beeraganna', 'bera ganna', 'beera ganna', 'beera',
      'save me', 'rescue', 'bear gonna', 'bare gonna', 'බේරගන්න', 'බේරාගන්න'
    ],
    'sinhala_ginnak_': [
      'ginnak', 'ginna', 'ginak', 'fire', 'burning', 'gin knock',
      'ගින්නක්', 'ගින්න', 'ගිනි', 'ගින්දර'
    ],
    'sinhala_balagena_': [
      'balagena', 'balaagena', 'bala gena', 'watch out', 'look out',
      'caution', 'bala gonna', 'ballerina', 'බලාගෙන', 'බලන්'
    ],
    'sinhala_ehata_wenna_': [
      'ehata wenna', 'ehatawenna', 'ehata', 'ehaata wenna', 'move aside',
      'move away', 'step back', 'get away', 'a hata', 'එහාට වෙන්න', 'එහාට'
    ],
    'sinhala_parissamin_': [
      'parissamin', 'parisamin', 'parissamen', 'be careful', 'take care',
      'careful', 'paris amin', 'paris man', 'පරිස්සමින්', 'පරිස්සමෙන්', 'පරිස්සම්'
    ],
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
    _lastSpeechTimeMs = 0;
    _keywordLockUntilMs = 0;
    _rollingIdx = 0;
    _total16kPushed = 0;
    _lastMlTimeMs = 0;
    _pendingEnvironmentSound = null;
    _pendingEnvironmentVotes = 0;
    _currentDisplayedKeyword = null;
    _latestSoundVolume = 0.25;
    _rollingBuf16k.fillRange(0, 16000, 0.0);

    _startVisualizerTicker();

    // 1. Hardware Microphone Stream via AudioRecorder (Guaranteed 100% Offline)
    final captureStarted = await _startAudioCapture();
    if (!captureStarted) {
      _isListening = false;
      _visualizerTicker?.cancel();
      _visualizerTicker = null;
      return false;
    }

    // 2. Also listen for Android Speech Recognizer events if available
    _startSpeechRecognizerChannel();

    _setSttStatus('Offline detection active. Say a Sinhala keyword or play sound.');
    return true;
  }

  void _startSpeechRecognizerChannel() {
    try {
      _speechSubscription?.cancel();
      _speechSubscription = _speechEvents.receiveBroadcastStream().listen(
        (event) {
          if (!_isListening || event is! Map) return;
          final type = (event['type'] ?? '').toString();
          if (type == 'partialResult' || type == 'finalResult') {
            final text = (event['text'] ?? '').toString().trim();
            if (text.isNotEmpty) {
              _processSpokenText(text);
            }
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );

      _speechChannel.invokeMethod('startListening').catchError((_) {});
    } catch (_) {}
  }

  void _processSpokenText(String rawText) {
    final clean = rawText
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0D80-\u0DFF]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _lastSpeechTimeMs = nowMs;

    // Check against the 8 Sinhala emergency keywords
    for (final entry in _sinhalaKeywords.entries) {
      final soundKey = entry.key;
      for (final pattern in entry.value) {
        if (clean.contains(pattern)) {
          if (nowMs < _keywordLockUntilMs && soundKey != _currentDisplayedKeyword) {
            return;
          }
          _keywordLockUntilMs = nowMs + 4000;
          _currentDisplayedKeyword = soundKey;
          _lastSpeechTimeMs = nowMs;
          _lastKeywordTriggerTimes[soundKey] = DateTime.fromMillisecondsSinceEpoch(nowMs);

          final display = _sinhalaLiveSpeechDisplay[soundKey] ?? rawText;
          _transcriptController.add(display);
          simulateSoundDetection(soundKey, confidence: 0.99, overrideCooldown: true);
          return;
        }
      }
    }

    // Non-emergency conversational speech displays full text, 0 alert cards!
    _transcriptController.add(rawText);
  }

  Future<bool> _startAudioCapture() async {
    try {
      _recordStreamSub?.cancel();
      _audioRecorder?.dispose();
      _audioRecorder = AudioRecorder();

      if (!await _audioRecorder!.hasPermission()) {
        return false;
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

    // Update real-time bouncing wave visualizer
    final double soundVol = (maxAmp * 4.0 + rms * 10.0).clamp(0.04, 1.0);
    _updateWaveformVolume(soundVol);

    const speechClasses = {
      'udaw',
      'beeraganna',
      'ginnak',
      'anathurak',
      'karadarayak',
      'balagena',
      'parissamin',
      'ehata_wenna',
    };

    const envSoundMap = {
      'ambulance_siren': 'ambulance',
      'fire_truck': 'fire_truck',
      'vehicle_horn': 'vehicle horns',
      'baby_crying': 'baby crying',
      'dog_barking': 'dog_bark_dataset',
    };

    final bool startupGraceOver = (nowMs - _listeningStartTimeMs >= 600);

    // Audio energy check (real sound, not electronic noise floor)
    final bool hasSoundEnergy = (maxAmp >= 0.025 || rms >= 0.005);
    if (hasSoundEnergy) {
      _lastSpeechTimeMs = nowMs;
    }

    // Run Neural Inference every 140ms on the 16,000-sample audio buffer
    if (_total16kPushed >= 8000 &&
        startupGraceOver &&
        (nowMs - _lastMlTimeMs >= 140)) {
      _lastMlTimeMs = nowMs;

      final List<double> window16k = List<double>.filled(16000, 0.0);
      double windowMax = 0.0;
      for (int i = 0; i < 16000; i++) {
        final s = _rollingBuf16k[(_rollingIdx - 16000 + i + 16000) % 16000];
        window16k[i] = s;
        final absS = s.abs();
        if (absS > windowMax) windowMax = absS;
      }

      // Skip electronic silence floor
      if (windowMax < 0.020 || rms < 0.004) {
        _pendingEnvironmentSound = null;
        _pendingEnvironmentVotes = 0;
        return;
      }

      // Automatic Gain Control (AGC) - amplifies near and far voice/sounds up to 30x
      final double gain = (0.50 / windowMax).clamp(1.0, 30.0);
      final List<double> normWindow = List<double>.filled(16000, 0.0);
      for (int i = 0; i < 16000; i++) {
        normWindow[i] = (window16k[i] * gain).clamp(-1.0, 1.0);
      }

      final pred = _neuralClassifier.predict(normWindow);
      if (pred == null) return;
      final allP = pred.allProbabilities;

      // Find top Sinhala speech class
      String? topSpeechClass;
      double topSpeechProb = 0.0;
      double secondSpeechProb = 0.0;
      for (final s in speechClasses) {
        final p = allP[s] ?? 0.0;
        if (p > topSpeechProb) {
          secondSpeechProb = topSpeechProb;
          topSpeechProb = p;
          topSpeechClass = s;
        } else if (p > secondSpeechProb) {
          secondSpeechProb = p;
        }
      }

      // Find top Environmental sound class
      String? topEnvClass;
      double topEnvProb = 0.0;
      for (final e in envSoundMap.keys) {
        final p = allP[e] ?? 0.0;
        if (p > topEnvProb) {
          topEnvProb = p;
          topEnvClass = e;
        }
      }

      final bool keywordLocked = (nowMs < _keywordLockUntilMs);

      // === 1. SINHALA EMERGENCY KEYWORDS DETECTION ===
      // Evaluated when top speech class probability is distinct and dominant
      final bool isDominantSpeech = topSpeechClass != null &&
          topSpeechProb >= 0.20 &&
          topSpeechProb >= secondSpeechProb * 1.25 &&
          topSpeechProb >= topEnvProb * 1.10;

      if (isDominantSpeech) {
        _lastSpeechTimeMs = nowMs;
        _pendingEnvironmentSound = null;
        _pendingEnvironmentVotes = 0;

        if (!keywordLocked || topSpeechClass == _currentDisplayedKeyword) {
          _keywordLockUntilMs = nowMs + 3500; // Hold for 3.5s
          _currentDisplayedKeyword = topSpeechClass;

          final soundKey = _classToSoundKey[topSpeechClass];
          if (soundKey != null) {
            _lastKeywordTriggerTimes[soundKey] = DateTime.fromMillisecondsSinceEpoch(nowMs);
            // Display formatted keyword in Live Speech box
            final displayText = _sinhalaLiveSpeechDisplay[soundKey] ?? topSpeechClass;
            _transcriptController.add(displayText);

            // Pop up ONLY that matching emergency alert card!
            unawaited(simulateSoundDetection(
              soundKey,
              confidence: math.max(topSpeechProb, 0.98),
              overrideCooldown: true,
            ));
          }
        }
        return; // Speech active: NEVER trigger environmental sounds!
      }

      // === 2. BACKGROUND ENVIRONMENTAL SOUNDS ===
      // Baby Crying, Ambulance Siren, Fire Truck, Vehicle Horns, Dog Barking
      // Evaluated ONLY when user is NOT speaking (at least 2.5s silence) and no keyword lock
      final bool userSpokeRecently = (nowMs - _lastSpeechTimeMs < 2500);

      if (!userSpokeRecently && !keywordLocked && topEnvClass != null) {
        final candidateSound = envSoundMap[topEnvClass];
        if (candidateSound != null) {
          const envThresholds = {
            'ambulance_siren': 0.45,
            'fire_truck': 0.55,
            'vehicle_horn': 0.45,
            'baby_crying': 0.40,
            'dog_barking': 0.45,
          };
          final double reqProb = envThresholds[topEnvClass] ?? 0.45;
          final bool isValid =
              topEnvProb >= reqProb && topEnvProb >= topSpeechProb * 1.35;

          if (isValid) {
            final lastAlert = _lastSoundAlertTimes[candidateSound];
            final bool cooldownPassed = lastAlert == null ||
                nowMs - lastAlert.millisecondsSinceEpoch >= 2500;

            if (_pendingEnvironmentSound == candidateSound) {
              _pendingEnvironmentVotes++;
            } else {
              _pendingEnvironmentSound = candidateSound;
              _pendingEnvironmentVotes = 1;
            }

            if (cooldownPassed && _pendingEnvironmentVotes >= 2) {
              _lastSoundAlertTimes[candidateSound] =
                  DateTime.fromMillisecondsSinceEpoch(nowMs);
              // Pop up ONLY that specific environmental sound card!
              // Do NOT overwrite Live Speech box!
              simulateSoundDetection(candidateSound, confidence: topEnvProb);
              _pendingEnvironmentVotes = 0;
              _pendingEnvironmentSound = null;
            }
          } else {
            _pendingEnvironmentSound = null;
            _pendingEnvironmentVotes = 0;
          }
        }
      }
    }
  }

  void stopListening() {
    _isListening = false;
    _visualizerTicker?.cancel();
    _visualizerTicker = null;
    _latestSoundVolume = 0.02;
    _waveformController.add([]);
    _currentDisplayedKeyword = null;
    _pendingEnvironmentSound = null;
    _pendingEnvironmentVotes = 0;

    _speechSubscription?.cancel();
    _speechSubscription = null;
    try {
      _speechChannel.invokeMethod('stopListening');
    } catch (_) {}

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
