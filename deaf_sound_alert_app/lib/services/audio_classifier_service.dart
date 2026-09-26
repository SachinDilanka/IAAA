import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_streamer/audio_streamer.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/detected_sound.dart';
import 'vibration_service.dart';
import 'smartwatch_service.dart';
import 'sound_config_service.dart';
import 'history_service.dart';
import 'native_neural_audio_classifier.dart';

class AudioClassifierService {
  static final AudioClassifierService _instance = AudioClassifierService._internal();
  factory AudioClassifierService() => _instance;
  AudioClassifierService._internal();

  final NativeNeuralAudioClassifier _neuralClassifier = NativeNeuralAudioClassifier();
  final stt.SpeechToText _speech = stt.SpeechToText();
  StreamSubscription<List<double>>? _audioStreamSubscription;

  Timer? _sttWatchdogTimer;
  bool _speechAvailable = false;
  String? _selectedLocaleId;
  bool _isListening = false;
  bool _useLocaleFallback = false;

  // 16,000 Hz circular rolling audio buffer (1 second)
  final List<double> _rollingBuf16k = List<double>.filled(16000, 0.0);
  int _rollingIdx = 0;
  int _total16kPushed = 0;
  int _hardwareSampleRate = 44100;
  int _lastPcmTimeMs = 0;
  int _lastMlTimeMs = 0;
  int _listeningStartTimeMs = 0;
  int _lastSpeechTimeMs = 0;
  DateTime? _lastGlobalAlertTime;

  final Map<String, DateTime> _lastKeywordTriggerTimes = {};
  final Map<String, DateTime> _classCooldown = {};

  final _controller = StreamController<DetectedSound>.broadcast();
  final _waveformController = StreamController<List<double>>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();

  bool get isListening => _isListening;
  Stream<DetectedSound> get onSoundDetected => _controller.stream;
  Stream<List<double>> get onWaveformUpdated => _waveformController.stream;
  Stream<String> get onTranscriptUpdated => _transcriptController.stream;

  final Map<String, String> _labelToSoundKey = {
    'ambulance_siren': 'ambulance',
    'ambulance': 'ambulance',
    'vehicle_horn': 'vehicle horns',
    'vehicle horns': 'vehicle horns',
    'baby_crying': 'baby crying',
    'baby crying': 'baby crying',
    'dog_barking': 'dog_bark_dataset',
    'dog_bark_dataset': 'dog_bark_dataset',
    'background_traffic': 'traffic',
    'traffic': 'traffic',
    'road': 'road',
    'udaw': 'sinhala_udaw_',
    'sinhala_udaw_': 'sinhala_udaw_',
    'anathurak': 'sinhala_anathurak_',
    'sinhala_anathurak_': 'sinhala_anathurak_',
    'beeraganna': 'sinhala_beraganna_',
    'sinhala_beraganna_': 'sinhala_beraganna_',
    'ginnak': 'sinhala_ginnak_',
    'sinhala_ginnak_': 'sinhala_ginnak_',
    'karadarayak': 'sinhala_karadarayak_',
    'sinhala_karadarayak_': 'sinhala_karadarayak_',
    'balagena': 'sinhala_balagena_',
    'sinhala_balagena_': 'sinhala_balagena_',
    'ehata_wenna': 'sinhala_ehata_wenna_',
    'sinhala_ehata_wenna_': 'sinhala_ehata_wenna_',
    'parissamin': 'sinhala_parissamin_',
    'sinhala_parissamin_': 'sinhala_parissamin_',
  };

  final Map<String, String> _displayNames = {
    'sinhala_udaw_': 'උදව් (Udaw)',
    'sinhala_anathurak_': 'අනතුරක් (Anathurak)',
    'sinhala_beraganna_': 'බේරාගන්න (Beraganna)',
    'sinhala_ginnak_': 'ගින්නක් (Ginnak)',
    'sinhala_karadarayak_': 'කරදරයක් (Karadarayak)',
    'sinhala_balagena_': 'බලාගෙන (Balaagena)',
    'sinhala_ehata_wenna_': 'එහාට වෙන්න (Ehata Wenna)',
    'sinhala_parissamin_': 'පරිස්සමින් (Parissamin)',
    'ambulance': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
    'baby crying': 'ළදරු හැඬීම (Baby Crying)',
    'vehicle horns': 'වාහන හොන් (Vehicle Horns)',
    'dog_bark_dataset': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
    'traffic': 'වාහන තදබදය (Traffic Noise)',
    'road': 'පාරේ ශබ්දය (Road Sounds)',
  };

  Future<void> init() async {
    try {
      await _neuralClassifier.loadModel();
      print('Native Neural Classifier loaded successfully!');
    } catch (e) {
      print('Neural Classifier load exception: $e');
    }

    try {
      _speechAvailable = await _speech.initialize(
        onError: (val) {
          print('SpeechToText onError: $val');
          _useLocaleFallback = true;
          _onSpeechEnded();
        },
        onStatus: (val) {
          print('SpeechToText onStatus: $val');
          if ((val == 'done' || val == 'notListening') && _isListening) {
            _onSpeechEnded();
          }
        },
      );

      if (_speechAvailable) {
        final locales = await _speech.locales();
        for (var loc in locales) {
          final id = loc.localeId.toLowerCase();
          if (id.startsWith('si') || id.contains('sinhala')) {
            _selectedLocaleId = loc.localeId;
            print('Found Sinhala locale: $_selectedLocaleId');
            break;
          }
        }
      }
    } catch (e) {
      print('SpeechToText init exception: $e');
    }
  }

  void _safeListenSpeech() async {
    if (!_isListening) return;

    if (!_speechAvailable) {
      try {
        _speechAvailable = await _speech.initialize(
          onError: (val) {
            print('SpeechToText onError: $val');
            _selectedLocaleId = null; // Clear failing locale and fallback to system default
            _onSpeechEnded();
          },
          onStatus: (val) {
            print('SpeechToText onStatus: $val');
            if ((val == 'done' || val == 'notListening') && _isListening) {
              _onSpeechEnded();
            }
          },
        );
      } catch (_) {}
    }

    if (!_speechAvailable) return;

    try {
      if (_speech.isListening) return;

      await _speech.listen(
        onResult: (result) {
          if (!_isListening) return;
          _lastSpeechTimeMs = DateTime.now().millisecondsSinceEpoch;
          final String rawWords = result.recognizedWords.trim();
          if (rawWords.isNotEmpty) {
            // Stream recognized words live into transcript box
            _transcriptController.add(rawWords);
            _processSpeechText(rawWords.toLowerCase());
          }
        },
        onSoundLevelChange: (level) {
          if (!_isListening) return;
          if (level > -35.0) {
            _lastSpeechTimeMs = DateTime.now().millisecondsSinceEpoch;
          }

          double norm = ((level + 40.0) / 50.0).clamp(0.08, 1.0);
          final math.Random rand = math.Random();
          final List<double> waveform = List.generate(40, (i) {
            double wave = math.sin((i * 0.3) + (DateTime.now().millisecondsSinceEpoch * 0.02)).abs() * 0.3;
            return (norm * (0.6 + wave + (rand.nextDouble() - 0.5) * 0.1)).clamp(0.08, 1.0);
          });
          _waveformController.add(waveform);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          pauseFor: const Duration(seconds: 10),
          listenFor: const Duration(hours: 2),
        ),
        localeId: _selectedLocaleId, // Use Sinhala locale if available, else null system default
      );
    } catch (e) {
      print('Speech listen error: $e');
      _selectedLocaleId = null;
      _onSpeechEnded();
    }
  }

  void _onSpeechEnded() {
    if (!_isListening) return;
    Timer(const Duration(milliseconds: 300), () {
      if (_isListening && !_speech.isListening) {
        _safeListenSpeech();
      }
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

    _isListening = true;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _listeningStartTimeMs = nowMs;
    _lastSpeechTimeMs = nowMs; // Initialize to start time so mic startup noise is suppressed
    _rollingIdx = 0;
    _total16kPushed = 0;

    // Always re-initialize SpeechToText AFTER permission grant
    try {
      _speechAvailable = await _speech.initialize(
        onError: (val) {
          print('SpeechToText onError: $val');
          _selectedLocaleId = null;
          _onSpeechEnded();
        },
        onStatus: (val) {
          print('SpeechToText onStatus: $val');
          if ((val == 'done' || val == 'notListening') && _isListening) {
            _onSpeechEnded();
          }
        },
      );

      if (_speechAvailable) {
        final locales = await _speech.locales();
        for (var loc in locales) {
          final id = loc.localeId.toLowerCase();
          if (id.startsWith('si') || id.contains('sinhala')) {
            _selectedLocaleId = loc.localeId;
            print('Found Sinhala locale: $_selectedLocaleId');
            break;
          }
        }
      }
    } catch (e) {
      print('Speech init error: $e');
    }

    // 1. High-Performance Audio Streamer for Real-Time Visualizer Waveform Line & Environmental Sound Peaks
    _startAudioStreamer();

    // 2. Speech Recognition Engine for Live Speech Transcripts & Instant Sinhala Voice Keyword Detection
    _safeListenSpeech();

    // 3. Persistent Watchdog to ensure STT service never dies or stays idle
    _sttWatchdogTimer?.cancel();
    _sttWatchdogTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_isListening && !_speech.isListening) {
        _safeListenSpeech();
      }
    });

    return true;
  }

  void _startAudioStreamer() {
    try {
      _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      final streamer = AudioStreamer();

      _audioStreamSubscription = streamer.audioStream.listen(
        (buffer) {
          if (!_isListening || buffer.isEmpty) return;
          _processPcmBuffer(buffer);
        },
        onError: (error) {
          print('AudioStreamer error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('AudioStreamer init error: $e');
    }
  }

  void _processPcmBuffer(List<double> rawBuffer) {
    if (rawBuffer.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastPcmTimeMs > 0) {
      final deltaMs = nowMs - _lastPcmTimeMs;
      if (deltaMs > 5 && deltaMs < 200) {
        final estimatedRate = (rawBuffer.length * 1000.0) / deltaMs;
        if (estimatedRate > 38000 && estimatedRate < 46000) {
          _hardwareSampleRate = 44100;
        } else if (estimatedRate >= 46000 && estimatedRate < 56000) {
          _hardwareSampleRate = 48000;
        } else if (estimatedRate >= 12000 && estimatedRate <= 24000) {
          _hardwareSampleRate = 16000;
        }
      }
    }
    _lastPcmTimeMs = nowMs;

    double maxRaw = 0.0;
    for (int i = 0; i < rawBuffer.length; i++) {
      final a = rawBuffer[i].abs();
      if (a > maxRaw) maxRaw = a;
    }
    final double normScale = maxRaw > 2.0 ? (1.0 / 32768.0) : 1.0;

    // Apply 3.0x software gain boost to capture quiet or distant speech & sounds
    const double gainBoost = 3.0;

    List<double> packet16k;
    if (_hardwareSampleRate == 16000) {
      packet16k = List<double>.generate(
        rawBuffer.length,
        (i) => (rawBuffer[i] * normScale * gainBoost).clamp(-1.0, 1.0),
      );
    } else {
      final int targetCount = ((rawBuffer.length * 16000) / _hardwareSampleRate).round();
      if (targetCount <= 0) return;
      packet16k = List<double>.filled(targetCount, 0.0);
      final double step = rawBuffer.length / targetCount.toDouble();
      for (int i = 0; i < targetCount; i++) {
        final int startIdx = (i * step).floor();
        final int endIdx = math.min(rawBuffer.length, ((i + 1) * step).floor());
        double sum = 0.0;
        int count = 0;
        for (int j = startIdx; j < endIdx; j++) {
          sum += rawBuffer[j] * normScale * gainBoost;
          count++;
        }
        double val = count > 0 ? (sum / count) : (rawBuffer[startIdx.clamp(0, rawBuffer.length - 1)] * normScale * gainBoost);
        packet16k[i] = val.clamp(-1.0, 1.0);
      }
    }

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

    final rms = math.sqrt(sumSquares / (packet16k.isEmpty ? 1 : packet16k.length));
    final double normalizedVol = (rms * 10.0).clamp(0.04, 1.0);

    // 40-band Real-time Audio Visualizer Frame Output (Line moves up/down dynamically)
    final math.Random rand = math.Random();
    final List<double> frame = List<double>.generate(40, (i) {
      final dist = (i - 20).abs();
      final spread = math.exp(-dist * 0.15);
      final wave = math.sin((i * 0.4) + (nowMs * 0.02)).abs() * 0.35;
      return (normalizedVol * (spread * 0.75 + wave + (rand.nextDouble() - 0.5) * 0.1)).clamp(0.04, 1.0);
    });
    _waveformController.add(frame);

    // Continuous Acoustic Neural Inference for Sinhala Keywords & Environmental Sounds (Every 300ms)
    if (_total16kPushed >= 16000 && (nowMs - _listeningStartTimeMs >= 1000) && rms > 0.010) {
      if (nowMs - _lastMlTimeMs > 300) {
        _lastMlTimeMs = nowMs;
        _runOfflineNeuralInference(rms);
      }
    }
  }

  void _runOfflineNeuralInference(double rms) {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    // Wait 1000ms after mic start to stabilize audio stream
    if (nowMs - _listeningStartTimeMs < 1000) return;

    // 2500ms global cooldown lockout between alerts to prevent rapid automatic switching
    if (_lastGlobalAlertTime != null && now.difference(_lastGlobalAlertTime!).inMilliseconds < 2500) {
      return;
    }

    final List<double> window1s = List<double>.filled(16000, 0.0);
    double winMaxAmp = 0.0;
    for (int i = 0; i < 16000; i++) {
      final val = _rollingBuf16k[(_rollingIdx - 16000 + i + 16000) % 16000];
      window1s[i] = val;
      final absV = val.abs();
      if (absV > winMaxAmp) winMaxAmp = absV;
    }

    // Reject distorted hardware clipping (> 0.98) or silent background noise (< 0.010)
    if (winMaxAmp > 0.98 || winMaxAmp < 0.010) return;

    final prediction = _neuralClassifier.predict(window1s);
    if (prediction == null) return;

    // 1. Sinhala Voice Emergency Keyword Classification (Udaw, Anathurak, Karadarayak, Ginnak, Beraganna, Balagena, Ehata Wenna, Parissamin)
    String? bestKeywordKey;
    double bestKeywordProb = 0.0;
    double sumKeywordProb = 0.0;

    for (var entry in prediction.allProbabilities.entries) {
      String label = entry.key;
      double p = entry.value;
      String? key = _labelToSoundKey[label];

      if (key != null && key.startsWith('sinhala_')) {
        sumKeywordProb += p;
        if (p > bestKeywordProb) {
          bestKeywordProb = p;
          bestKeywordKey = key;
        }
      }
    }

    // If a Sinhala emergency keyword is detected with strong acoustic confidence (prob >= 0.80), trigger keyword alert card!
    if (bestKeywordKey != null && (bestKeywordProb >= 0.80 || sumKeywordProb >= 0.88)) {
      final lastTime = _lastKeywordTriggerTimes[bestKeywordKey];
      if (lastTime == null || now.difference(lastTime).inMilliseconds > 2500) {
        _lastKeywordTriggerTimes[bestKeywordKey] = now;
        _lastGlobalAlertTime = now;
        _lastSpeechTimeMs = nowMs;

        simulateSoundDetection(bestKeywordKey, confidence: math.max(bestKeywordProb, 0.95));
      }
      return; // Early return for voice keywords
    }

    // 2. Environmental Emergency Sound Classification (Baby Crying, Dog Barking, Ambulance Siren, Vehicle Horns, Traffic Noise)
    // Suppress environmental sound classification IF human speech/keyword occurred within last 2500ms
    if (nowMs - _lastSpeechTimeMs < 2500) return;

    String topLabel = prediction.label;
    String? soundKey = _labelToSoundKey[topLabel];

    if (soundKey == null ||
        soundKey.startsWith('sinhala_') ||
        topLabel == 'background_traffic') {
      return;
    }

    double prob = prediction.probability;
    final top5 = prediction.top5Probabilities.values.toList();
    double secondBest = top5.length > 1 ? top5[1] : 0.0;
    double margin = prob - secondBest;

    // Environmental sound detection thresholds for Dog Barking, Vehicle Horns, Baby Crying, Ambulance Siren, Traffic Noise
    if (prob >= 0.50 && margin >= 0.10 && rms >= 0.015 && winMaxAmp >= 0.05) {
      _lastGlobalAlertTime = now;
      _classCooldown[soundKey] = now;

      simulateSoundDetection(soundKey, confidence: prob);
    }
  }

  void _processSpeechText(String rawText) {
    // Sanitize transcript by removing zero-width spaces/joiners, punctuation, and extra whitespace
    final String sanitized = rawText
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'[^\w\s\u0D80-\u0DFF]'), ' ')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (sanitized.isEmpty) return;

    _lastSpeechTimeMs = DateTime.now().millisecondsSinceEpoch;

    final Map<String, List<String>> keywordPatterns = {
      'sinhala_udaw_': [
        'udaw', 'udaww', 'udau', 'udawwa', 'udawwak', 'udauwa', 'udav', 'udavv', 'help', 'uda', 'udaa', 'udawu', 'udauw', 'sos', 'emergency',
        'උදව්', 'උදව්වක්', 'උදවු', 'උදවු කරන්න', 'උදව් කරන්න', 'උදව්ව', 'උදව්ක්', 'උද'
      ],
      'sinhala_anathurak_': [
        'anathurak', 'anatura', 'anathura', 'anathurai', 'anaturak', 'danger', 'anaturai', 'anathurac', 'accident', 'warning',
        'අනතුරක්', 'අනතුර', 'අනතුරයි'
      ],
      'sinhala_beraganna_': [
        'beraganna', 'beeraganna', 'bcraganna', 'pera', 'beera', 'beragan', 'save', 'beragannako', 'berannako', 'save me', 'rescue',
        'බේරාගන්න', 'බේරගන්න', 'බේරා', 'බේර', 'බේරන්න', 'බේරාගන්නකෝ', 'බේරගන්නකෝ'
      ],
      'sinhala_ginnak_': [
        'ginnak', 'ginna', 'ginnaki', 'ginnac', 'fire', 'gina', 'ginak', 'firefire', 'burning',
        'ගින්නක්', 'ගින්න', 'ගිනි', 'ගිණි'
      ],
      'sinhala_karadarayak_': [
        'karadarayak', 'karadara', 'karadarai', 'karadarayac', 'trouble', 'karadarak', 'problem', 'distress',
        'කරදරයක්', 'කරදර', 'කරදරයි', 'කරදරේ'
      ],
      'sinhala_balagena_': [
        'balagena', 'balagenna', 'balaagena', 'balaganna', 'balang', 'watch', 'lookout', 'balan', 'watch out', 'look out', 'caution',
        'බලාගෙන', 'බලන්', 'බලාගෙනම', 'බලන්න'
      ],
      'sinhala_ehata_wenna_': [
        'ehata', 'wenna', 'ehatawenna', 'move', 'ehata wenna', 'move away', 'step back', 'get away',
        'එහාට', 'වෙන්න', 'එහාටවෙන්න', 'එහාට වෙන්න'
      ],
      'sinhala_parissamin_': [
        'parissamin', 'parisamin', 'parissamen', 'parisamen', 'parissam', 'parisam', 'careful', 'parissamen', 'be careful', 'safe', 'take care',
        'පරිස්සමින්', 'පරිස්සමෙන්', 'පරිසමින්', 'පරිස්සම්'
      ],
    };

    final now = DateTime.now();

    // Select ONLY the single most relevant matching keyword (longest pattern match)
    String? matchedKey;
    int longestPatternLen = 0;

    keywordPatterns.forEach((key, patterns) {
      for (var pattern in patterns) {
        if (sanitized.contains(pattern)) {
          if (pattern.length > longestPatternLen) {
            longestPatternLen = pattern.length;
            matchedKey = key;
          }
        }
      }
    });

    if (matchedKey != null) {
      final lastTime = _lastKeywordTriggerTimes[matchedKey];
      if (lastTime == null || now.difference(lastTime).inMilliseconds > 1500) {
        _lastKeywordTriggerTimes[matchedKey!] = now;
        _lastGlobalAlertTime = now;
        simulateSoundDetection(matchedKey!, confidence: 0.98);
      }
    }
  }

  void stopListening() {
    _isListening = false;
    _sttWatchdogTimer?.cancel();
    _sttWatchdogTimer = null;
    if (_speech.isListening) {
      _speech.stop();
    }
    _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
  }

  Future<void> simulateSoundDetection(String soundKey, {double confidence = 0.92}) async {
    final soundConfig = SoundConfigService().getConfig(soundKey);
    if (soundConfig == null || !soundConfig.isEnabled) return;

    final event = DetectedSound(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      soundKey: soundConfig.key,
      soundName: soundConfig.name,
      category: soundConfig.category,
      priority: soundConfig.priority,
      confidence: confidence,
      timestamp: DateTime.now(),
    );

    // Save log
    await HistoryService().addEvent(event);

    // Trigger Phone Vibration
    await VibrationService().triggerVibration(event.priority);

    // Send Alert Push Notification to Android Phone & Smartwatch Yesido IO 39
    await SmartwatchService().sendAlertToWatch(event);

    // Emit event to UI
    _controller.add(event);
  }

  void dispose() {
    stopListening();
    _controller.close();
    _waveformController.close();
    _transcriptController.close();
  }
}
