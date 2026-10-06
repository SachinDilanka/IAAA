import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audio_streamer/audio_streamer.dart';
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

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isRestartingStt = false;
  Timer? _sttWatchdogTimer;
  Timer? _sttRestartTimer;

  AudioStreamer? _audioStreamer;
  StreamSubscription? _pcmStreamSubscription;

  bool _isListening = false;
  double _latestSoundVolume = 0.02;
  final List<double> _visualizerBars = List<double>.filled(40, 0.15);

  // 16,000 Hz circular rolling audio buffer (1 second = 16,000 samples)
  final List<double> _rollingBuf16k = List<double>.filled(16000, 0.0);
  int _rollingIdx = 0;
  int _total16kPushed = 0;
  int _hardwareSampleRate = 16000;
  int _lastMlTimeMs = 0;
  int _listeningStartTimeMs = 0;
  int _lastSpeechTimeMs = 0;

  // Adaptive ambient noise floor tracking (raw mic RMS)
  double _noiseFloor = 0.008;

  final Map<String, DateTime> _lastKeywordTriggerTimes = {};
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

  void _setSttStatus(String status) {
    if (status == _sttStatus) return;
    _sttStatus = status;
    _sttStatusController.add(status);
  }

  // Exact Live Speech display strings for 8 Sinhala emergency keywords
  static final Map<String, String> _sinhalaLiveSpeechDisplay = {
    'sinhala_udaw_': 'udaw  →  උදව් (Udaw - Help)',
    'sinhala_beraganna_': 'beeraganna  →  බේරගන්න (Beraganna - Save Me)',
    'sinhala_ginnak_': 'ginnak  →  ගින්නක් (Ginnak - Fire)',
    'sinhala_anathurak_': 'anathurak  →  අනතුරක් (Anathurak - Danger)',
    'sinhala_karadarayak_': 'karadarayak  →  කරදරයක් (Karadarayak - Trouble)',
    'sinhala_balagena_': 'balagena  →  බලාගෙන (Balaagena - Watch Out)',
    'sinhala_ehata_wenna_': 'ehata wenna  →  එහාට වෙන්න (Ehata Wenna - Move Aside)',
    'sinhala_parissamin_': 'parissamin  →  පරිස්සමින් (Parissamin - Be Careful)',
  };

  // Exact Live Speech display strings for 6 Environmental sounds
  static final Map<String, String> _envLiveSpeechDisplay = {
    'ambulance_siren': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
    'fire_truck': 'ගිනි නිවන රථ ශබ්දය (Fire Truck Siren)',
    'vehicle_horn': 'වාහන හොන් (Vehicle Horns)',
    'baby_crying': 'ළදරු හැඬීම (Baby Crying)',
    'dog_barking': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
    'background_traffic': 'වාහන තදබදය (Traffic Noise)',
  };

  // General display lookup
  static final Map<String, String> _classToLiveSpeechDisplay = {
    'udaw': 'udaw  →  උදව් (Udaw - Help)',
    'beeraganna': 'beeraganna  →  බේරගන්න (Beraganna - Save Me)',
    'ginnak': 'ginnak  →  ගින්නක් (Ginnak - Fire)',
    'anathurak': 'anathurak  →  අනතුරක් (Anathurak - Danger)',
    'karadarayak': 'karadarayak  →  කරදරයක් (Karadarayak - Trouble)',
    'balagena': 'balagena  →  බලාගෙන (Balaagena - Watch Out)',
    'ehata_wenna': 'ehata wenna  →  එහාට වෙන්න (Ehata Wenna - Move Aside)',
    'parissamin': 'parissamin  →  පරිස්සමින් (Parissamin - Be Careful)',
    'ambulance_siren': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
    'fire_truck': 'ගිනි නිවන රථ ශබ්දය (Fire Truck Siren)',
    'vehicle_horn': 'වාහන හොන් (Vehicle Horns)',
    'baby_crying': 'ළදරු හැඬීම (Baby Crying)',
    'dog_barking': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
    'background_traffic': 'වාහන තදබදය (Traffic Noise)',
  };

  // Maps neural network class names to SoundConfig service keys
  static final Map<String, String> _classToSoundKey = {
    'udaw': 'sinhala_udaw_',
    'beeraganna': 'sinhala_beraganna_',
    'ginnak': 'sinhala_ginnak_',
    'anathurak': 'sinhala_anathurak_',
    'karadarayak': 'sinhala_karadarayak_',
    'balagena': 'sinhala_balagena_',
    'ehata_wenna': 'sinhala_ehata_wenna_',
    'parissamin': 'sinhala_parissamin_',
    'ambulance_siren': 'ambulance',
    'fire_truck': 'fire_truck',
    'vehicle_horn': 'vehicle horns',
    'baby_crying': 'baby crying',
    'dog_barking': 'dog_bark_dataset',
    'background_traffic': 'traffic',
  };

  // Comprehensive speech-to-text keyword patterns for the 8 Sinhala emergencies
  static final Map<String, List<String>> _sinhalaKeywordPatterns = {
    'sinhala_udaw_': [
      'udaw', 'udaww', 'udawwa', 'udau', 'udauwa', 'udav', 'udavv', 'udawu', 'udauw', 'help', 'sos', 'emergency',
      'උදව්', 'උදව්වක්', 'උදවු', 'උදවු කරන්න', 'උදව් කරන්න', 'උදව්ව', 'උදව්ක්'
    ],
    'sinhala_anathurak_': [
      'anathurak', 'anatura', 'anathura', 'anathurai', 'anaturak', 'danger', 'anaturai', 'anathurac', 'accident', 'warning', 'anatur', 'anathur',
      'අනතුරක්', 'අනතුර', 'අනතුරයි', 'අනතුරු'
    ],
    'sinhala_beraganna_': [
      'beraganna', 'beeraganna', 'bera ganna', 'beera ganna', 'bcraganna', 'beera', 'beragan', 'beeragan', 'save me', 'rescue', 'beragannako',
      'බේරාගන්න', 'බේරගන්න', 'බේරාගන්නකෝ', 'බේරගන්නකෝ', 'බේරන්න'
    ],
    'sinhala_ginnak_': [
      'ginnak', 'ginna', 'ginak', 'ginnaki', 'ginnac', 'fire', 'burning', 'gindara',
      'ගින්නක්', 'ගින්න', 'ගිනි', 'ගිණි', 'ගින්දර'
    ],
    'sinhala_karadarayak_': [
      'karadarayak', 'karadara', 'karadarai', 'karadarayac', 'trouble', 'karadarak', 'problem', 'distress',
      'කරදරයක්', 'කරදර', 'කරදරයි', 'කරදරේ'
    ],
    'sinhala_balagena_': [
      'balagena', 'balagenna', 'balaagena', 'bala gena', 'balaganna', 'balang', 'watch out', 'look out', 'caution',
      'බලාගෙන', 'බලන්', 'බලාගෙනම'
    ],
    'sinhala_ehata_wenna_': [
      'ehata wenna', 'ehatawenna', 'ehata', 'ehaata wenna', 'move aside', 'move away', 'step back', 'get away',
      'එහාට වෙන්න', 'එහාටවෙන්න', 'එහාට'
    ],
    'sinhala_parissamin_': [
      'parissamin', 'parisamin', 'parissamen', 'parisamen', 'parissam', 'parisam', 'be careful', 'take care', 'careful',
      'පරිස්සමින්', 'පරිස්සමෙන්', 'පරිසමින්', 'පරිස්සම්'
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
        Timer.periodic(const Duration(milliseconds: 20), (timer) {
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
    _rollingIdx = 0;
    _total16kPushed = 0;
    _lastMlTimeMs = 0;
    _latestSoundVolume = 0.25;
    _noiseFloor = 0.008;
    _rollingBuf16k.fillRange(0, 16000, 0.0);

    _startVisualizerTicker();

    _setSttStatus('Live Speech & Sound Detection Active');

    // 1. Continuous Speech-to-Text for word-by-word Live Speech & keyword alerts
    _safeListenSpeech();

    _sttWatchdogTimer?.cancel();
    _sttWatchdogTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!_isListening) {
        timer.cancel();
        return;
      }
      if (!_speech.isListening && !_isRestartingStt) {
        _safeListenSpeech();
      }
    });

    // 2. Continuous Hardware Microphone Stream for offline acoustic neural network
    _startAudioStreamer();

    return true;
  }

  void _safeListenSpeech() async {
    if (!_isListening || _isRestartingStt) return;
    if (_speech.isListening) return;

    _isRestartingStt = true;

    try {
      if (!_speechAvailable) {
        _speechAvailable = await _speech.initialize(
          onError: (val) => _onSpeechError(val.errorMsg),
          onStatus: (val) {
            if ((val == 'done' || val == 'notListening') && _isListening) {
              _onSpeechDone();
            }
          },
        );
      }

      if (!_speechAvailable || !_isListening) {
        _isRestartingStt = false;
        return;
      }

      await _speech.listen(
        onResult: (result) {
          if (!_isListening) return;
          final rawWords = result.recognizedWords.trim();
          if (rawWords.isNotEmpty) {
            _lastSpeechTimeMs = DateTime.now().millisecondsSinceEpoch;
            _processSpeechText(rawWords);
          }
        },
        onSoundLevelChange: (level) {
          if (!_isListening) return;
          final double vol =
              (0.20 + (level.clamp(-2.0, 10.0) / 10.0)).clamp(0.18, 1.0);
          _updateWaveformVolume(vol);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          pauseFor: const Duration(seconds: 30),
          listenFor: const Duration(hours: 1),
          localeId: null,
        ),
      );
    } catch (e) {
      _onSpeechError(e.toString());
    } finally {
      _isRestartingStt = false;
    }
  }

  void _onSpeechDone() {
    if (!_isListening) return;
    _sttRestartTimer?.cancel();
    _sttRestartTimer = Timer(const Duration(milliseconds: 300), () {
      if (_isListening && !_speech.isListening && !_isRestartingStt) {
        _safeListenSpeech();
      }
    });
  }

  void _onSpeechError(String errorMsg) {
    if (!_isListening) return;
    _sttRestartTimer?.cancel();
    _sttRestartTimer = Timer(const Duration(milliseconds: 600), () {
      if (_isListening && !_speech.isListening && !_isRestartingStt) {
        _safeListenSpeech();
      }
    });
  }

  int _levenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = math.min(v1[j] + 1, math.min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[s2.length];
  }

  bool _isKeywordMatch(String fullText, String pattern) {
    if (fullText.contains(pattern)) return true;

    final words = fullText.split(RegExp(r'\s+'));
    final patternWords = pattern.split(RegExp(r'\s+'));

    if (patternWords.length == 1) {
      for (final w in words) {
        if (w == pattern) return true;
        if (pattern.length >= 5 && w.length >= 4) {
          final dist = _levenshtein(w, pattern);
          if (dist <= 1) return true;
        }
      }
    } else {
      for (int i = 0; i <= words.length - patternWords.length; i++) {
        final phrase = words.sublist(i, i + patternWords.length).join(' ');
        if (phrase == pattern) return true;
        if (phrase.length >= 6) {
          final dist = _levenshtein(phrase, pattern);
          if (dist <= 2) return true;
        }
      }
    }
    return false;
  }

  void _processSpeechText(String rawWords) {
    final sanitized = rawWords
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0D80-\u0DFF]'), ' ')
        .trim();
    final now = DateTime.now();

    // 1. Check if spoken text matches any of the 8 Sinhala emergency keywords
    for (var entry in _sinhalaKeywordPatterns.entries) {
      final key = entry.key;
      for (var pattern in entry.value) {
        if (_isKeywordMatch(sanitized, pattern)) {
          final lastTime = _lastKeywordTriggerTimes[key];
          if (lastTime != null &&
              now.difference(lastTime).inMilliseconds < 2000) {
            return;
          }
          _lastKeywordTriggerTimes[key] = now;
          _lastSpeechTimeMs = now.millisecondsSinceEpoch;

          // 1. Display formatted keyword in Live Speech box FIRST
          final display = _sinhalaLiveSpeechDisplay[key] ?? rawWords;
          _transcriptController.add(display);

          // 2. Pop up ONLY that matching Sinhala emergency card!
          simulateSoundDetection(key, confidence: 0.99, overrideCooldown: true);
          return;
        }
      }
    }

    // 2. Normal Speech (English or other words): Display word-by-word in Live Speech!
    // NO alert card pops up! Voice NEVER triggers environmental sounds!
    _transcriptController.add(rawWords);
  }

  void _startAudioStreamer() async {
    try {
      _pcmStreamSubscription?.cancel();
      _pcmStreamSubscription = null;
      _audioStreamer = AudioStreamer();

      _audioStreamer!.sampleRate = 16000;
      _hardwareSampleRate = 16000;

      _pcmStreamSubscription = _audioStreamer!.audioStream.listen(
        (buffer) {
          if (!_isListening || buffer.isEmpty) return;
          _processPcmBuffer(buffer);
        },
        onError: (error) {
          // Keep running smoothly even if stream reports an error
        },
        cancelOnError: false,
      );

      Future.delayed(const Duration(milliseconds: 250), () async {
        try {
          if (_audioStreamer != null) {
            final rate = await _audioStreamer!.actualSampleRate;
            if (rate >= 8000 && rate <= 96000) {
              _hardwareSampleRate = rate;
            }
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  void _processPcmBuffer(List<double> rawBuffer) {
    if (rawBuffer.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // 1. Measure raw peak amplitude
    double maxRaw = 0.0;
    for (int i = 0; i < rawBuffer.length; i++) {
      final a = rawBuffer[i].abs();
      if (a > maxRaw) maxRaw = a;
    }

    final double normScale = maxRaw > 2.0 ? (1.0 / 32768.0) : 1.0;

    // Resample to 16,000 Hz if hardware rate differs
    List<double> packet16k;
    if (_hardwareSampleRate == 16000) {
      packet16k = List<double>.generate(
        rawBuffer.length,
        (i) => (rawBuffer[i] * normScale).clamp(-1.0, 1.0),
      );
    } else {
      final int targetCount =
          ((rawBuffer.length * 16000) / _hardwareSampleRate).round();
      if (targetCount <= 0) return;
      packet16k = List<double>.filled(targetCount, 0.0);
      final double ratio =
          (rawBuffer.length - 1) / (targetCount > 1 ? (targetCount - 1) : 1);
      for (int i = 0; i < targetCount; i++) {
        final double srcPos = i * ratio;
        final int idx = srcPos.floor();
        final double frac = srcPos - idx;
        final double s0 = rawBuffer[idx] * normScale;
        final double s1 = (idx + 1 < rawBuffer.length)
            ? rawBuffer[idx + 1] * normScale
            : s0;
        packet16k[i] = (s0 + (s1 - s0) * frac).clamp(-1.0, 1.0);
      }
    }

    // Push into 16,000 Hz circular rolling buffer
    double sumSquares = 0.0;
    double maxAmp = 0.0;
    for (int i = 0; i < packet16k.length; i++) {
      final s = packet16k[i];
      final absS = s.abs();
      if (absS > maxAmp) maxAmp = absS;
      sumSquares += s * s;

      _rollingBuf16k[_rollingIdx] = s;
      _rollingIdx = (_rollingIdx + 1) % 16000;
      _total16kPushed++;
    }

    final double rms =
        math.sqrt(sumSquares / (packet16k.isEmpty ? 1 : packet16k.length));

    // Update adaptive background noise floor
    if (rms < _noiseFloor) {
      _noiseFloor = _noiseFloor * 0.90 + rms * 0.10;
    } else {
      _noiseFloor = _noiseFloor * 0.995 + rms * 0.005;
    }

    // Update real-time bouncing wave visualizer
    final double soundVol = (maxAmp * 4.0 + rms * 10.0).clamp(0.04, 1.0);
    _updateWaveformVolume(soundVol);

    // Run Neural Network Inference when sound energy is present
    final bool hasSoundEnergy = (maxAmp >= 0.003 || rms >= 0.0015);
    final bool startupGraceOver = (nowMs - _listeningStartTimeMs >= 350);

    if (_total16kPushed >= 8000 &&
        startupGraceOver &&
        hasSoundEnergy &&
        (nowMs - _lastMlTimeMs >= 100)) {
      _lastMlTimeMs = nowMs;

      // Extract 1-second rolling window
      final List<double> window1s = List<double>.filled(16000, 0.0);
      double windowMax = 0.0;
      for (int i = 0; i < 16000; i++) {
        final s = _rollingBuf16k[(_rollingIdx - 16000 + i + 16000) % 16000];
        window1s[i] = s;
        final absS = s.abs();
        if (absS > windowMax) windowMax = absS;
      }

      // Dynamic Automatic Gain Control (AGC) up to 50x for far speech or sounds
      final List<double> normalizedWindow = List<double>.filled(16000, 0.0);
      final double gain =
          windowMax > 0.001 ? (0.55 / windowMax).clamp(1.0, 50.0) : 1.0;
      for (int i = 0; i < 16000; i++) {
        normalizedWindow[i] = (window1s[i] * gain).clamp(-1.0, 1.0);
      }

      // Run 100% offline pure-Dart neural network
      final pred = _neuralClassifier.predict(normalizedWindow);
      if (pred != null) {
        final allP = pred.allProbabilities;

        const speechClasses = {
          'udaw',
          'beeraganna',
          'ginnak',
          'anathurak',
          'karadarayak',
          'balagena',
          'ehata_wenna',
          'parissamin',
        };

        const envSoundMap = {
          'ambulance_siren': 'ambulance',
          'fire_truck': 'fire_truck',
          'vehicle_horn': 'vehicle horns',
          'baby_crying': 'baby crying',
          'dog_barking': 'dog_bark_dataset',
          'background_traffic': 'traffic',
        };

        // Find top Sinhala speech class
        String? bestSpeechClass;
        double bestSpeechProb = 0.0;
        for (final s in speechClasses) {
          final p = allP[s] ?? 0.0;
          if (p > bestSpeechProb) {
            bestSpeechProb = p;
            bestSpeechClass = s;
          }
        }

        // Find top environmental class
        String? bestEnvClass;
        double bestEnvProb = 0.0;
        for (final e in envSoundMap.keys) {
          final p = allP[e] ?? 0.0;
          if (p > bestEnvProb) {
            bestEnvProb = p;
            bestEnvClass = e;
          }
        }

        // 1. If acoustic model strongly detects one of the 8 Sinhala keywords (offline backup):
        if (bestSpeechClass != null &&
            bestSpeechProb >= 0.70 &&
            bestSpeechProb > bestEnvProb * 1.4) {
          final soundKey = _classToSoundKey[bestSpeechClass] ?? bestSpeechClass;
          final lastAlert = _lastKeywordTriggerTimes[soundKey];
          final bool cooldownPassed = lastAlert == null ||
              nowMs - lastAlert.millisecondsSinceEpoch >= 2000;

          if (cooldownPassed) {
            _lastKeywordTriggerTimes[soundKey] =
                DateTime.fromMillisecondsSinceEpoch(nowMs);
            _lastSpeechTimeMs = nowMs;

            final display = _sinhalaLiveSpeechDisplay[soundKey] ??
                _classToLiveSpeechDisplay[bestSpeechClass] ??
                bestSpeechClass;

            // 1. Display recognized Sinhala word in the Live Speech box FIRST
            _transcriptController.add(display);

            // 2. Pop up matching Sinhala alert card
            simulateSoundDetection(soundKey,
                confidence: bestSpeechProb, overrideCooldown: true);
          }
          return; // STOP! User voice NEVER triggers environmental sounds!
        }

        // 2. Background Environmental Sounds (Ambulance, Fire Truck, Horn, Baby, Dog, Traffic)
        // User voice lock: strictly require NO SPEECH within the last 3.0 seconds!
        final bool speechActiveRecently = (nowMs - _lastSpeechTimeMs < 3000);

        if (!speechActiveRecently && bestEnvClass != null) {
          final soundKey = envSoundMap[bestEnvClass];
          const envThresholds = {
            'ambulance_siren': 0.70,
            'fire_truck': 0.70,
            'vehicle_horn': 0.70,
            'baby_crying': 0.70,
            'dog_barking': 0.70,
            'background_traffic': 0.88,
          };
          final double requiredProb = envThresholds[bestEnvClass] ?? 0.75;

          if (soundKey != null &&
              bestEnvProb >= requiredProb &&
              bestSpeechProb < 0.20) {
            final lastAlert = _lastSoundAlertTimes[soundKey];
            final bool cooldownPassed = lastAlert == null ||
                nowMs - lastAlert.millisecondsSinceEpoch >= 2500;

            if (cooldownPassed) {
              final display = _envLiveSpeechDisplay[bestEnvClass] ??
                  _classToLiveSpeechDisplay[bestEnvClass] ??
                  bestEnvClass;

              // 1. Display detected environmental sound in Live Speech box
              _transcriptController.add(display);

              // 2. Pop up ONLY that specific environmental sound card!
              simulateSoundDetection(soundKey, confidence: bestEnvProb);
            }
          }
        }
      }
    }
  }

  void stopListening() {
    _isListening = false;
    _sttWatchdogTimer?.cancel();
    _sttWatchdogTimer = null;
    _sttRestartTimer?.cancel();
    _sttRestartTimer = null;
    _visualizerTicker?.cancel();
    _visualizerTicker = null;
    _latestSoundVolume = 0.02;
    _waveformController.add([]);

    if (_speech.isListening) {
      _speech.stop();
    }
    _pcmStreamSubscription?.cancel();
    _pcmStreamSubscription = null;
    _audioStreamer = null;
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
