import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/detected_sound.dart';
import 'vibration_service.dart';
import 'flashlight_service.dart';
import 'smartwatch_service.dart';
import 'sound_config_service.dart';
import 'history_service.dart';

class AudioClassifierService {
  static final AudioClassifierService _instance =
      AudioClassifierService._internal();
  factory AudioClassifierService() => _instance;
  AudioClassifierService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isRestartingStt = false;
  Timer? _sttWatchdogTimer;
  Timer? _sttRestartTimer;

  bool _isListening = false;
  double _latestSoundVolume = 0.02;
  final List<double> _visualizerBars = List<double>.filled(40, 0.15);

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
    'ambulance': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
    'fire_truck': 'ගිනි නිවන රථ ශබ්දය (Fire Truck Siren)',
    'vehicle horns': 'වාහන හොන් (Vehicle Horns)',
    'baby crying': 'ළදරු හැඬීම (Baby Crying)',
    'dog_bark_dataset': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
    'traffic': 'වාහන තදබදය (Traffic Noise)',
  };

  // Comprehensive speech-to-text keyword patterns for the 8 Sinhala emergencies
  static final Map<String, List<String>> _sinhalaKeywordPatterns = {
    'sinhala_udaw_': [
      'udaw', 'udaww', 'udawwa', 'udau', 'udauwa', 'udav', 'udavv', 'udawu', 'udauw', 'help', 'sos', 'emergency',
      'you dow', 'ooh dow', 'wood owl', 'who dow',
      'උදව්', 'උදව්වක්', 'උදවු', 'උදවු කරන්න', 'උදව් කරන්න', 'උදව්ව', 'උදව්ක්'
    ],
    'sinhala_anathurak_': [
      'anathurak', 'anatura', 'anathura', 'anathurai', 'anaturak', 'danger', 'anaturai', 'anathurac', 'accident', 'warning', 'anatur', 'anathur',
      'another act',
      'අනතුරක්', 'අනතුර', 'අනතුරයි', 'අනතුරු'
    ],
    'sinhala_beraganna_': [
      'beraganna', 'beeraganna', 'bera ganna', 'beera ganna', 'bcraganna', 'beera', 'beragan', 'beeragan', 'save me', 'rescue', 'beragannako',
      'bear gonna',
      'බේරාගන්න', 'බේරගන්න', 'බේරාගන්නකෝ', 'බේරගන්නකෝ', 'බේරන්න'
    ],
    'sinhala_ginnak_': [
      'ginnak', 'ginna', 'ginak', 'ginnaki', 'ginnac', 'fire', 'burning', 'gindara', 'gin knock', 'gin nac',
      'ගින්නක්', 'ගින්න', 'ගිනි', 'ගිණි', 'ගින්දර'
    ],
    'sinhala_karadarayak_': [
      'karadarayak', 'karadara', 'karadarai', 'karadarayac', 'trouble', 'karadarak', 'problem', 'distress', 'kara da rai',
      'කරදරයක්', 'කරදර', 'කරදරයි', 'කරදරේ'
    ],
    'sinhala_balagena_': [
      'balagena', 'balagenna', 'balaagena', 'bala gena', 'balaganna', 'balang', 'watch out', 'look out', 'caution', 'bala gonna',
      'බලාගෙන', 'බලන්', 'බලාගෙනම'
    ],
    'sinhala_ehata_wenna_': [
      'ehata wenna', 'ehatawenna', 'ehata', 'ehaata wenna', 'ehata wena', 'move aside', 'move away', 'step back', 'get away',
      'එහාට වෙන්න', 'එහාටවෙන්න', 'එහාට'
    ],
    'sinhala_parissamin_': [
      'parissamin', 'parisamin', 'parissamen', 'parisamen', 'parissam', 'parisam', 'paris amin', 'be careful', 'take care', 'careful',
      'පරිස්සමින්', 'පරිස්සමෙන්', 'පරිසමින්', 'පරිස්සම්'
    ],
  };

  // Environmental sound keywords & sound imitations
  static final Map<String, List<String>> _environmentalKeywordPatterns = {
    'ambulance': [
      'ambulance', 'siren', 'ambulance siren', 'wee ow', 'weeow', 'wee-ow',
      'nee naw', 'neenaw', 'nee-naw', 'wee woo', 'weewoo', 'emergency siren',
      'ගිලන්', 'ගිලන් රථ', 'සයිරන්', 'ගිලන්රථ'
    ],
    'fire_truck': [
      'fire truck', 'firetruck', 'fire engine', 'fire alarm', 'truck siren',
      'ගිනි නිවන', 'ගිනි නිවන රථ', 'ගිනි නිවනරථ'
    ],
    'vehicle horns': [
      'horn', 'horns', 'vehicle horn', 'car horn', 'truck horn',
      'beep beep', 'beepbeep', 'honk honk', 'honkhonk', 'beep', 'honk',
      'හොන්', 'පීප්', 'නාලාව'
    ],
    'baby crying': [
      'baby crying', 'baby cry', 'crying baby', 'infant crying',
      'waa waa', 'waawaa', 'wah wah', 'wahwah', 'waa', 'wah',
      'crying', 'cry', 'ළදරු', 'හැඬීම', 'ළදරු හැඬීම', 'අඬනවා'
    ],
    'dog_bark_dataset': [
      'dog barking', 'dog bark', 'barking dog', 'puppy barking',
      'woof woof', 'woofwoof', 'arf arf', 'arfarf', 'ruff ruff',
      'woof', 'barking', 'bark', 'bow wow', 'bowwow',
      'බල්ලා', 'බුරන', 'බුරනවා', 'බල්ලන්'
    ],
    'traffic': [
      'traffic', 'traffic noise', 'traffic sound', 'car sound',
      'road sound', 'vroom', 'rumble', 'highway',
      'වාහන තදබදය', 'තදබදය', 'පාරේ ශබ්ද'
    ],
  };

  Timer? _visualizerTicker;

  Future<void> init() async {}

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

    _isListening = true;
    _latestSoundVolume = 0.25;

    _startVisualizerTicker();

    _setSttStatus('Listening for speech… Say any word near or far from mic');

    // Start dedicated, uncontested Speech-to-Text engine for word-by-word Live Speech
    _safeListenSpeech();

    _sttWatchdogTimer?.cancel();
    _sttWatchdogTimer =
        Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!_isListening) {
        timer.cancel();
        return;
      }
      if (!_speech.isListening && !_isRestartingStt) {
        _safeListenSpeech();
      }
    });

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
          debugLogging: false,
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
          pauseFor: const Duration(seconds: 4),
          listenFor: const Duration(hours: 1),
          localeId: null, // Uses device default language for maximum compatibility
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
    _sttRestartTimer = Timer(const Duration(milliseconds: 200), () {
      if (_isListening && !_speech.isListening && !_isRestartingStt) {
        _safeListenSpeech();
      }
    });
  }

  void _onSpeechError(String errorMsg) {
    if (!_isListening) return;
    _sttRestartTimer?.cancel();
    _sttRestartTimer = Timer(const Duration(milliseconds: 400), () {
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
        if (pattern.length >= 4 && w.length >= 4) {
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
    if (rawWords.isEmpty) return;
    final now = DateTime.now();

    final sanitized = rawWords
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0D80-\u0DFF]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 1. Check if spoken text matches any of the 8 Sinhala emergency keywords
    for (var entry in _sinhalaKeywordPatterns.entries) {
      final key = entry.key;
      for (var pattern in entry.value) {
        if (_isKeywordMatch(sanitized, pattern)) {
          final lastTime = _lastKeywordTriggerTimes[key];
          if (lastTime != null &&
              now.difference(lastTime).inMilliseconds < 1800) {
            return;
          }
          _lastKeywordTriggerTimes[key] = now;

          // 1. Display formatted keyword in Live Speech box FIRST
          final display = _sinhalaLiveSpeechDisplay[key] ?? rawWords;
          _transcriptController.add(display);

          // 2. Pop up ONLY that matching Sinhala emergency card!
          simulateSoundDetection(key, confidence: 0.99, overrideCooldown: true);
          return;
        }
      }
    }

    // 2. Check if spoken text matches environmental sound patterns
    for (var entry in _environmentalKeywordPatterns.entries) {
      final key = entry.key;
      for (var pattern in entry.value) {
        if (_isKeywordMatch(sanitized, pattern)) {
          final lastTime = _lastSoundAlertTimes[key];
          if (lastTime != null &&
              now.difference(lastTime).inMilliseconds < 2500) {
            return;
          }
          _lastSoundAlertTimes[key] = now;

          // 1. Display environmental sound in Live Speech box FIRST
          final display = _envLiveSpeechDisplay[key] ?? rawWords;
          _transcriptController.add(display);

          // 2. Pop up ONLY that matching environmental sound card!
          simulateSoundDetection(key, confidence: 0.95, overrideCooldown: true);
          return;
        }
      }
    }

    // 3. Normal Speech (English or other words):
    // Display EVERY single word spoken in real time word-by-word into the Live Speech box!
    // NO alert card pops up! NO automatic popups!
    _transcriptController.add(rawWords);
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
