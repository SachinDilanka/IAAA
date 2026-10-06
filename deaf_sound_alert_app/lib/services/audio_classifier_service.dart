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
  bool _sinhalaLocaleRejected = false;
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

  int _lastSttInitAttemptMs = 0;

  Future<bool> _ensureSpeechInitialized() async {
    if (_speechAvailable) return true;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastSttInitAttemptMs < 4000 && _lastSttInitAttemptMs != 0) {
      return false;
    }
    _lastSttInitAttemptMs = nowMs;
    try {
      _speechAvailable = await _speech.initialize(
        onError: (val) => _onSpeechError(val.errorMsg),
        onStatus: (val) {
          if ((val == 'done' || val == 'notListening') && _isListening) {
            _onSpeechDone();
          }
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }

    if (!_speechAvailable) {
      _setSttStatus('Speech-to-text not available on this device');
      return false;
    }

    if (_selectedLocaleId == null && !_sinhalaLocaleRejected) {
      try {
        final locales = await _speech.locales();
        for (var loc in locales) {
          final id = loc.localeId.toLowerCase().replaceAll('-', '_');
          if (id == 'si_lk' || id.startsWith('si_')) {
            _selectedLocaleId = loc.localeId;
            break;
          }
        }
      } catch (_) {}
    }
    return true;
  }

  void _safeListenSpeech() async {
    if (!_isListening || _isRestartingStt) return;
    if (_speech.isListening) return;

    _isRestartingStt = true;
    try {
      final bool ok = await _ensureSpeechInitialized();
      if (!ok || !_isListening) return;

      final String? targetLocale =
          _sinhalaLocaleRejected ? null : _selectedLocaleId;

      await _speech.listen(
        onResult: (result) {
          if (!_isListening) return;
          final String rawWords = result.recognizedWords.trim();
          if (rawWords.isNotEmpty) {
            _setSttStatus('Listening (Live speech active)');

            // 1. Immediately display live words in the Live Speech box
            final String formatted = _formatTranscriptWithSinhala(rawWords);
            _transcriptController.add(
                formatted == rawWords ? rawWords : '$rawWords  →  $formatted');

            // 2. Check for emergency keywords based on recognized words
            _processSpeechText(rawWords.toLowerCase());
          }
        },
        onSoundLevelChange: (level) {
          if (!_isListening) return;
          double soundVol =
              (0.25 + (level.clamp(-2.0, 10.0) / 10.0)).clamp(0.18, 1.0);
          _updateWaveformVolume(soundVol);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.deviceDefault,
          partialResults: true,
          cancelOnError: false,
          pauseFor: const Duration(seconds: 15),
          listenFor: const Duration(minutes: 30),
          localeId: targetLocale,
        ),
      );

      _setSttStatus(targetLocale == null
          ? 'Listening for speech (Device Language)…'
          : 'Listening for speech (Sinhala $targetLocale)…');
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
        err.contains('server')) {
      if (!_sinhalaLocaleRejected) {
        _sinhalaLocaleRejected = true;
        _selectedLocaleId = null;
        _setSttStatus('Listening (Device Language fallback)');
      }
    }

    Timer(const Duration(milliseconds: 350), () {
      if (_isListening && !_speech.isListening && !_isRestartingStt) {
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
    _isRestartingStt = false;
    _latestSoundVolume = 0.25;

    // Start 50 FPS smooth visualizer animation ticker
    _startVisualizerTicker();

    _speechAvailable = false;
    _lastSttInitAttemptMs = 0;
    _sttStatus = '';
    _setSttStatus('Starting Live Speech Detection…');

    // Continuous Speech Engine for transcribing live speech (Sinhala & English) in real time
    _safeListenSpeech();

    // Watchdog timer to ensure speech recognition stays continuously listening
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

  bool _isKeywordMatch(String text, String pattern) {
    final textLower = text.toLowerCase().trim();
    final patternLower = pattern.toLowerCase().trim();

    if (textLower.isEmpty || patternLower.isEmpty) return false;

    // 1. Direct equality or sentence contains exact phrase
    if (textLower == patternLower || textLower.contains(patternLower)) {
      return true;
    }

    // 2. Concatenated clean text match (ignores spaces and hyphens)
    final textClean = textLower.replaceAll(RegExp(r'[^\w\u0D80-\u0DFF]'), '');
    final patternClean =
        patternLower.replaceAll(RegExp(r'[^\w\u0D80-\u0DFF]'), '');

    if (textClean.isNotEmpty && patternClean.isNotEmpty) {
      if (textClean == patternClean || textClean.contains(patternClean)) {
        return true;
      }
      if (patternClean.length >= 5 &&
          textClean.length >= 4 &&
          patternClean.startsWith(textClean)) {
        return true;
      }
    }

    // 3. Word-by-word token analysis with fuzzy matching
    final words = textLower
        .split(RegExp(r'[^\w\u0D80-\u0DFF]+'))
        .where((w) => w.isNotEmpty)
        .toList();

    for (final word in words) {
      if (word == patternClean) return true;

      // Only compare words of substantial length (>= 3 chars) to avoid matching short stop words
      if (word.length >= 3 && patternClean.length >= 3) {
        if (word.startsWith(patternClean)) return true;
        if (patternClean.length >= 5 &&
            word.length >= 4 &&
            patternClean.startsWith(word)) {
          return true;
        }

        // Fuzzy Levenshtein Distance
        if ((word.length - patternClean.length).abs() <= 2) {
          final int dist = _levenshtein(word, patternClean);
          final int maxDist = (patternClean.length <= 4) ? 1 : 2;
          if (dist <= maxDist) {
            return true;
          }
        }
      }
    }

    return false;
  }

  String _formatTranscriptWithSinhala(String rawWords) {
    final String lower = rawWords.toLowerCase();

    final Map<String, String> wordToSinhala = {
      'udaw': 'උදව් (Udaw - Help)',
      'udau': 'උදව් (Udaw - Help)',
      'udaww': 'උදව් (Udaw - Help)',
      'uda': 'උදව් (Udaw - Help)',
      'udav': 'උදව් (Udaw - Help)',
      'help': 'උදව් (Udaw - Help)',
      'උදව්': 'උදව් (Udaw - Help)',
      'උදවු': 'උදව් (Udaw - Help)',
      'උදව්වක්': 'උදව් (Udaw - Help)',
      'beraganna': 'බේරගන්න (Beraganna - Save Me)',
      'beeraganna': 'බේරගන්න (Beraganna - Save Me)',
      'beeragana': 'බේරගන්න (Beraganna - Save Me)',
      'beragana': 'බේරගන්න (Beraganna - Save Me)',
      'bera ganna': 'බේරගන්න (Beraganna - Save Me)',
      'beera ganna': 'බේරගන්න (Beraganna - Save Me)',
      'save me': 'බේරගන්න (Beraganna - Save Me)',
      'බේරගන්න': 'බේරගන්න (Beraganna - Save Me)',
      'බේරාගන්න': 'බේරගන්න (Beraganna - Save Me)',
      'ginnak': 'ගින්නක් (Ginnak - Fire)',
      'ginna': 'ගින්නක් (Ginnak - Fire)',
      'fire': 'ගින්නක් (Ginnak - Fire)',
      'ගින්නක්': 'ගින්නක් (Ginnak - Fire)',
      'ගින්න': 'ගින්නක් (Ginnak - Fire)',
      'anathurak': 'අනතුරක් (Anathurak - Danger)',
      'anatura': 'අනතුරක් (Anathurak - Danger)',
      'danger': 'අනතුරක් (Anathurak - Danger)',
      'accident': 'අනතුරක් (Anathurak - Danger)',
      'අනතුරක්': 'අනතුරක් (Anathurak - Danger)',
      'karadarayak': 'කරදරයක් (Karadarayak - Trouble)',
      'karadara': 'කරදරයක් (Karadarayak - Trouble)',
      'trouble': 'කරදරයක් (Karadarayak - Trouble)',
      'කරදරයක්': 'කරදරයක් (Karadarayak - Trouble)',
      'balagena': 'බලාගෙන (Balaagena - Watch Out)',
      'watch out': 'බලාගෙන (Balaagena - Watch Out)',
      'look out': 'බලාගෙන (Balaagena - Watch Out)',
      'බලාගෙන': 'බලාගෙන (Balaagena - Watch Out)',
      'ehata wenna': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
      'ehata': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
      'move aside': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
      'එහාට වෙන්න': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
      'parissamin': 'පරිස්සමින් (Parissamin - Be Careful)',
      'parisamin': 'පරිස්සමින් (Parissamin - Be Careful)',
      'parissamen': 'පරිස්සමින් (Parissamin - Be Careful)',
      'be careful': 'පරිස්සමින් (Parissamin - Be Careful)',
      'careful': 'පරිස්සමින් (Parissamin - Be Careful)',
      'පරිස්සමින්': 'පරිස්සමින් (Parissamin - Be Careful)',
      'kohomada': 'කොහොමද (Kohomada - How are you)',
      'කොහොමද': 'කොහොමද (Kohomada - How are you)',
      'ayubowan': 'ආයුබෝවන් (Ayubowan - Welcome)',
      'ආයුබෝවන්': 'ආයුබෝවන් (Ayubowan - Welcome)',
      'sthuthiyi': 'ස්තූතියි (Sthuthiyi - Thank you)',
      'ස්තූතියි': 'ස්තූතියි (Sthuthiyi - Thank you)',
      'subha dawasak': 'සුබ දවසක් (Subha Dawasak - Have a nice day)',
      'සුබ දවසක්': 'සුබ දවසක් (Subha Dawasak - Have a nice day)',
      'hello': 'හලෝ (Hello)',
      'halo': 'හලෝ (Hello)',
      'හලෝ': 'හලෝ (Hello)',
      'hari': 'හරි (Hari - Okay)',
      'හරි': 'හරි (Hari - Okay)',
      'hondayi': 'හොඳයි (Hondayi - Good)',
      'හොඳයි': 'හොඳයි (Hondayi - Good)',
      'ow': 'ඔව් (Ow - Yes)',
      'ඔව්': 'ඔව් (Ow - Yes)',
      'naa': 'නෑ (Naa - No)',
      'නෑ': 'නෑ (Naa - No)',
      'mokakda': 'මොකක්ද (Mokakda - What)',
      'මොකක්ද': 'මොකක්ද (Mokakda - What)',
      'kauda': 'කවුද (Kauda - Who)',
      'කවුද': 'කවුද (Kauda - Who)',
      'koheda': 'කොහෙද (Koheda - Where)',
      'කොහෙද': 'කොහෙද (Koheda - Where)',
      'ambulance': 'ගිලන් රථය (Ambulance)',
      'siren': 'සයිරන් (Siren)',
    };

    for (var entry in wordToSinhala.entries) {
      if (_isKeywordMatch(lower, entry.key)) {
        return entry.value;
      }
    }

    return rawWords;
  }

  void _processSpeechText(String rawText) {
    final String sanitized = rawText
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'[^\w\s\u0D80-\u0DFF-]'), ' ')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (sanitized.isEmpty) return;

    final Map<String, List<String>> keywordPatterns = {
      'sinhala_udaw_': [
        'udaw',
        'udaww',
        'udau',
        'uda',
        'udaa',
        'udawwa',
        'udawwak',
        'udauwa',
        'udav',
        'udavv',
        'help',
        'udawu',
        'udauw',
        'sos',
        'emergency',
        'wood how',
        'you down',
        'who do',
        'උදව්',
        'උදව්වක්',
        'උදවු',
        'උදවු කරන්න',
        'උදව් කරන්න',
        'උදව්ව',
        'උදව්ක්',
        'උදව'
      ],
      'sinhala_beraganna_': [
        'beraganna',
        'beeraganna',
        'beeragana',
        'beragana',
        'mawa beraganna',
        'mawa beeraganna',
        'bcraganna',
        'beragannako',
        'berannako',
        'bera ganna',
        'beera ganna',
        'beera gana',
        'bera gana',
        'biragana',
        'biraganna',
        'save me',
        'save',
        'rescue',
        'beer gonna',
        'better gonna',
        'bear gonna',
        'bare gonna',
        'බේරගන්න',
        'බේරාගන්න',
        'බේරාගන්නකෝ',
        'බේරගන්නකෝ',
        'බේරන්න',
        'මාව බේරගන්න',
        'මාව බේරාගන්න'
      ],
      'sinhala_ginnak_': [
        'ginnak',
        'ginna',
        'ginnaki',
        'ginnac',
        'fire',
        'ginak',
        'burning',
        'green neck',
        'ගින්නක්',
        'ගින්න',
        'ගිනි',
        'ගිණි'
      ],
      'sinhala_anathurak_': [
        'anathurak',
        'anatura',
        'anathura',
        'anathurai',
        'anaturak',
        'anaturai',
        'anathurac',
        'accident',
        'anatur',
        'anathur',
        'danger',
        'warning',
        'අනතුරක්',
        'අනතුර',
        'අනතුරයි'
      ],
      'sinhala_karadarayak_': [
        'karadarayak',
        'karadara',
        'karadarai',
        'karadarayac',
        'karadarak',
        'karadhara',
        'trouble',
        'problem',
        'distress',
        'කරදරයක්',
        'කරදර',
        'කරදරයි',
        'කරදරේ'
      ],
      'sinhala_balagena_': [
        'balagena',
        'balagenna',
        'balaagena',
        'balaganna',
        'watch out',
        'look out',
        'bala gena',
        'balagen',
        'ballerina',
        'caution',
        'onna balagena',
        'ඔන්න බලාගෙන',
        'බලාගෙන',
        'බලන්',
        'බලාගෙනම',
        'බලාගෙන ඉන්න'
      ],
      'sinhala_ehata_wenna_': [
        'ehata wenna',
        'eheta wenna',
        'ehatawenna',
        'ehetawenna',
        'ehata',
        'eheta',
        'move aside',
        'step back',
        'get away',
        'ehata wenda',
        'eheta wenda',
        'එහාට වෙන්න',
        'එහාටවෙන්න',
        'එහාට',
        'එහාට වෙනවා'
      ],
      'sinhala_parissamin_': [
        'parissamin',
        'parisamin',
        'parissamen',
        'parisamen',
        'parissam',
        'parisam',
        'be careful',
        'take care',
        'careful',
        'paris am in',
        'parissameng',
        'parissaming',
        'prissin',
        'parissin',
        'prissamin',
        'prissamen',
        'පරිස්සමින්',
        'පරිස්සමෙන්',
        'පරිසමින්',
        'පරිස්සම්',
        'පරිස්සම් වෙන්න'
      ],
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
        'wee oo',
        'weeoo',
        'wail',
        'wailing',
        'සයිරන්',
        'ගිලන් රථ',
        'ගිලන්'
      ],
      'fire_truck': [
        'fire truck',
        'fire engine',
        'fire siren',
        'ගිනි නිවන',
        'ගිනි නිවන රථ'
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
        'පීප්',
        'බීප්',
        'බීප් බීප්',
        'වාහන හොන්'
      ],
      'baby crying': [
        'waa-waa',
        'waawaa',
        'waa waa',
        'wah-wah',
        'wahwah',
        'wah wah',
        'cry',
        'crying',
        'cries',
        'baby',
        'babies',
        'baby crying',
        'baby cry',
        'weeping',
        'ළදරු',
        'හැඬීම',
        'අඬනවා',
        'අඬන',
        'ළදරු හැඬීම'
      ],
      'dog_bark_dataset': [
        'woof-woof',
        'woofwoof',
        'woof woof',
        'arf-arf',
        'arfarf',
        'ruff-ruff',
        'ruffruff',
        'woof',
        'bark',
        'barks',
        'barking',
        'dog barking',
        'dog bark',
        'බල්ලා',
        'බුරනවා',
        'බුරන',
        'බල්ලා බුරනවා'
      ],
      'traffic': [
        'traffic',
        'traffic noise',
        'road noise',
        'car noise',
        'vroom',
        'rumble',
        'වාහන තදබදය'
      ],
    };

    final now = DateTime.now();

    for (var entry in keywordPatterns.entries) {
      final key = entry.key;
      for (var pattern in entry.value) {
        if (_isKeywordMatch(sanitized, pattern)) {
          final lastTime = _lastKeywordTriggerTimes[key];
          if (lastTime != null &&
              now.difference(lastTime).inMilliseconds < 1800) {
            return;
          }
          _lastKeywordTriggerTimes[key] = now;

          // Trigger emergency alert card directly based on recognized speech
          simulateSoundDetection(key, confidence: 0.99, overrideCooldown: true);
          return;
        }
      }
    }
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
          now.difference(lastSoundTime).inMilliseconds < 3000) {
        return;
      }
      if (_lastEmittedAlertTime != null &&
          now.difference(_lastEmittedAlertTime!).inMilliseconds < 1200) {
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
