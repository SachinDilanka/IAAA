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

  Timer? _sttWatchdogTimer;
  bool _speechAvailable = false;
  String? _selectedLocaleId;
  bool _isListening = false;
  bool _isRestartingStt = false;
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
  static final Map<String, String> _soundKeyToLiveSpeechDisplay = {
    'sinhala_udaw_': 'udaw  →  උදව් (Udaw - Help)',
    'sinhala_beraganna_': 'beeraganna  →  බේරගන්න (Beraganna - Save Me)',
    'sinhala_ginnak_': 'ginnak  →  ගින්නක් (Ginnak - Fire)',
    'sinhala_anathurak_': 'anathurak  →  අනතුරක් (Anathurak - Danger)',
    'sinhala_karadarayak_': 'karadarayak  →  කරදරයක් (Karadarayak - Trouble)',
    'sinhala_balagena_': 'balagena  →  බලාගෙන (Balaagena - Watch Out)',
    'sinhala_ehata_wenna_': 'ehata wenna  →  එහාට වෙන්න (Ehata Wenna - Move Aside)',
    'sinhala_parissamin_': 'parissamin  →  පරිස්සමින් (Parissamin - Be Careful)',
  };

  // Comprehensive keyword patterns for the 8 Sinhala keywords (English phonetics + Sinhala script)
  static final Map<String, List<String>> _sinhalaKeywordPatterns = {
    'sinhala_udaw_': [
      'udaw',
      'udau',
      'udawu',
      'udawa',
      'help',
      'help me',
      'woodow',
      'you down',
      'who the',
      'how to help',
      'need help',
      'out of',
      'උදව්',
      'උදවු',
      'උදව් කරන්න',
      'උදව්ව',
      'උදව්ක්',
      'උදව',
    ],
    'sinhala_beraganna_': [
      'beeraganna',
      'beraganna',
      'beeragana',
      'beragana',
      'save me',
      'save',
      'rescue',
      'better gonna',
      'bear gonna',
      'beer gonna',
      'mawa beraganna',
      'mawa beeraganna',
      'bera ganna',
      'beera ganna',
      'biragana',
      'biraganna',
      'බේරගන්න',
      'බේරාගන්න',
      'බේරන්න',
      'මාව බේරගන්න',
      'බේරගන්නකෝ',
    ],
    'sinhala_ginnak_': [
      'ginnak',
      'ginna',
      'fire',
      'burning',
      'green neck',
      'ginak',
      'ginnac',
      'ගින්නක්',
      'ගින්න',
      'ගිනි',
      'ගිණි',
    ],
    'sinhala_anathurak_': [
      'anathurak',
      'anatura',
      'anathura',
      'danger',
      'warning',
      'accident',
      'anaturak',
      'anatur',
      'anathur',
      'anathurac',
      'another',
      'අනතුරක්',
      'අනතුර',
      'අනතුරයි',
    ],
    'sinhala_karadarayak_': [
      'karadarayak',
      'karadara',
      'karadarai',
      'trouble',
      'problem',
      'distress',
      'karadarak',
      'karadarayac',
      'කරදරයක්',
      'කරදර',
      'කරදරයි',
      'කරදරේ',
    ],
    'sinhala_balagena_': [
      'balagena',
      'balaagena',
      'balaganna',
      'watch out',
      'look out',
      'caution',
      'balagen',
      'ballerina',
      'බලාගෙන',
      'බලන්',
      'බලාගෙනම',
    ],
    'sinhala_ehata_wenna_': [
      'ehata wenna',
      'eheta wenna',
      'ehatawenna',
      'ehetawenna',
      'move aside',
      'step back',
      'get away',
      'ehata',
      'eheta',
      'එහාට වෙන්න',
      'එහාටවෙන්න',
      'එහාට',
    ],
    'sinhala_parissamin_': [
      'parissamin',
      'parisamin',
      'parissamen',
      'be careful',
      'take care',
      'careful',
      'parissam',
      'parisam',
      'paris am in',
      'පරිස්සමින්',
      'පරිස්සමෙන්',
      'පරිසමින්',
      'පරිස්සම්',
    ],
  };

  // Environmental sound patterns (only triggered when environmental sounds are recognized)
  static final Map<String, List<String>> _environmentalPatterns = {
    'ambulance': [
      'wee-ow',
      'weeow',
      'wee ow',
      'nee-naw',
      'neenaw',
      'nee naw',
      'siren',
      'sirens',
      'ambulance',
      'ambulance siren',
      'wail',
      'wailing',
      'emergency siren',
      'සයිරන්',
      'ගිලන් රථ',
    ],
    'fire_truck': [
      'fire truck',
      'fire engine',
      'fire siren',
      'fire alarm',
      'ගිනි නිවන',
      'ගිනි නිවන රථ',
    ],
    'vehicle horns': [
      'beep-beep',
      'beepbeep',
      'beep beep',
      'honk-honk',
      'honkhonk',
      'honk honk',
      'honk',
      'honks',
      'honking',
      'beep',
      'beeps',
      'beeping',
      'car horn',
      'vehicle horn',
      'horn sound',
      'horn',
      'horns',
      'හොන්',
      'වාහන හොන්',
    ],
    'baby crying': [
      'waa-waa',
      'waawaa',
      'waa waa',
      'wah-wah',
      'wahwah',
      'wah wah',
      'baby crying',
      'baby cry',
      'crying baby',
      'weeping baby',
      'ළදරු හැඬීම',
      'ළදරු',
      'හැඬීම',
    ],
    'dog_bark_dataset': [
      'woof-woof',
      'woofwoof',
      'woof woof',
      'arf-arf',
      'arfarf',
      'ruff-ruff',
      'dog barking',
      'dog bark',
      'barking dog',
      'woof',
      'bark',
      'barking',
      'බල්ලා බුරන',
      'බල්ලා',
    ],
    'traffic': [
      'traffic',
      'traffic noise',
      'road noise',
      'car noise',
      'engine roar',
      'vroom',
      'rumble',
      'වාහන තදබදය',
    ],
  };

  Timer? _visualizerTicker;

  Future<void> init() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (val) => _onSpeechError(val.errorMsg),
        onStatus: (val) {
          if ((val == 'done' || val == 'notListening') && _isListening) {
            _onSpeechDone();
          }
        },
      );

      if (_speechAvailable) {
        try {
          final locales = await _speech.locales();
          for (var loc in locales) {
            final id = loc.localeId.toLowerCase().replaceAll('-', '_');
            if (id == 'si_lk' || id.startsWith('si_') || id.contains('sinhala')) {
              _selectedLocaleId = loc.localeId;
              break;
            }
          }
        } catch (_) {}
      }
    } catch (_) {
      _speechAvailable = false;
    }
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

    _isListening = true;
    _latestSoundVolume = 0.25;

    _startVisualizerTicker();

    _setSttStatus('Listening for speech & sounds…');

    // Start continuous Speech Recognition engine with exclusive microphone access
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
          localeId: _selectedLocaleId,
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
    Timer(const Duration(milliseconds: 250), () {
      if (_isListening && !_speech.isListening && !_isRestartingStt) {
        _safeListenSpeech();
      }
    });
  }

  void _onSpeechError(String errorMsg) {
    if (!_isListening) return;
    final String err = errorMsg.toLowerCase();
    if (err.contains('language') ||
        err.contains('unsupported') ||
        err.contains('unavailable') ||
        err.contains('network') ||
        err.contains('server')) {
      if (_selectedLocaleId != null) {
        _selectedLocaleId = null; // Fall back to device default language seamlessly
      }
    }
    Timer(const Duration(milliseconds: 350), () {
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

    // 1. Check the 8 Sinhala emergency keywords FIRST
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

          // 1. Display recognized Sinhala word in the Live Speech box FIRST
          final display = _soundKeyToLiveSpeechDisplay[key] ?? rawWords;
          _transcriptController.add(display);

          // 2. Pop up the matching Sinhala emergency alert card immediately!
          simulateSoundDetection(key, confidence: 0.99, overrideCooldown: true);
          return;
        }
      }
    }

    // 2. Check environmental sound patterns (only when actual environmental words are heard/spoken)
    for (var entry in _environmentalPatterns.entries) {
      final key = entry.key;
      for (var pattern in entry.value) {
        if (_isKeywordMatch(sanitized, pattern)) {
          final lastTime = _lastSoundAlertTimes[key];
          if (lastTime != null &&
              now.difference(lastTime).inMilliseconds < 3000) {
            return;
          }
          _lastSoundAlertTimes[key] = now;

          _transcriptController.add(rawWords);
          simulateSoundDetection(key, confidence: 0.95, overrideCooldown: true);
          return;
        }
      }
    }

    // 3. Normal Speech: Display exactly what the user said word-by-word! NO ALERT CARD POPS UP!
    _transcriptController.add(rawWords);
  }

  void stopListening() {
    _isListening = false;
    _sttWatchdogTimer?.cancel();
    _sttWatchdogTimer = null;
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

