import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
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

  static const MethodChannel _speechChannel =
      MethodChannel('com.deafalert.app/speech');
  static const EventChannel _speechEvents =
      EventChannel('com.deafalert.app/speech/events');
  StreamSubscription? _speechSubscription;

  bool _isListening = false;
  double _latestSoundVolume = 0.02;
  final List<double> _visualizerBars = List<double>.filled(40, 0.15);

  int _keywordLockUntilMs = 0;
  String? _currentDisplayedKeyword;

  final Map<String, DateTime> _lastSoundAlertTimes = {};
  final Map<String, DateTime> _lastKeywordTriggerTimes = {};
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

  // Comprehensive speech keyword patterns for all 8 Sinhala emergencies
  // Matches across Sinhala unicode, Romanized words, and English phonetic variations
  static const Map<String, List<String>> _sinhalaKeywords = {
    'sinhala_udaw_': [
      'udaw', 'udaww', 'udawwa', 'udau', 'udauwa', 'udav', 'udavv', 'udaaw', 'udaav', 'uda',
      'help', 'sos', 'emergency',
      'wood owl', 'woodowl', 'you dow', 'ooh dow', 'who dow', 'you down', 'u down', 'u dow',
      'you do', 'who do', 'you dive', 'you dial', 'you dough', 'you know', 'you have',
      'you doll', 'you dumb', 'you dao', 'out down', 'how do', 'hudaw', 'hudau', 'oo dow',
      'udo', 'dow', 'dao', 'you d have', 'you d how',
      'උදව්', 'උදවු', 'උදව්ව', 'උදව් කරන්න', 'උදව්වක්', 'උදව්ක්'
    ],
    'sinhala_karadarayak_': [
      'karadarayak', 'karadara', 'karadarai', 'karadarak', 'karadare', 'karadhara',
      'kara darayak', 'karadara yak', 'trouble', 'problem', 'distress',
      'kara da rai', 'kara da rak', 'car the rack', 'cardiac', 'car direct', 'care direct',
      'color dark', 'car dark', 'color direct', 'current direct', 'character', 'canada act',
      'car door act', 'corridor act', 'corridor', 'car the act', 'card direct', 'car react',
      'can direct', 'care cardiac',
      'කරදරයක්', 'කරදර', 'කරදරයි', 'කරදරේ', 'කරදරයක්ද'
    ],
    'sinhala_anathurak_': [
      'anathurak', 'anatura', 'anathura', 'anathurai', 'anaturak', 'anaturai', 'anathurac',
      'anatur', 'anathur', 'anaturu', 'danger', 'warning', 'accident',
      'another act', 'another track', 'another rock', 'another rack', 'another truck',
      'another hack', 'another pack', 'another back', 'another app', 'another attack',
      'a natural act', 'another',
      'අනතුරක්', 'අනතුර', 'අනතුරයි', 'අනතුරු', 'අනතුරක්ද'
    ],
    'sinhala_beraganna_': [
      'beraganna', 'beeraganna', 'bera ganna', 'beera ganna', 'bcraganna', 'beera',
      'beragan', 'beeragan', 'beragannako', 'beeragannako', 'beranna',
      'save me', 'rescue', 'bear gonna', 'bare gonna', 'better gonna', 'beer gonna',
      'baritone', 'para gonna', 'wear gonna', 'where gonna', 'there gonna', 'care gonna',
      'fair gonna', 'bear gunner', 'bear gone', 'bare gone',
      'බේරගන්න', 'බේරාගන්න', 'බේරගන්නකෝ', 'බේරාගන්නකෝ', 'බේරන්න'
    ],
    'sinhala_ginnak_': [
      'ginnak', 'ginna', 'ginak', 'ginnaki', 'ginnac', 'gindara', 'ginnaa',
      'fire', 'burning', 'blaze', 'gin knock', 'gin nac', 'get knock', 'good knock',
      'give knock', 'game knock', 'in knock', 'kidnap', 'kin knock', 'key knock',
      'knock', 'gin',
      'ගින්නක්', 'ගින්න', 'ගිනි', 'ගිණි', 'ගින්දර', 'ගින්නක්ද'
    ],
    'sinhala_balagena_': [
      'balagena', 'balagenna', 'balaagena', 'bala gena', 'balaganna', 'balang',
      'balagene', 'bala gone', 'watch out', 'look out', 'caution', 'careful',
      'bala gonna', 'ballerina', 'baller gonna', 'body gonna', 'bottle gonna',
      'by la gonna', 'follow gonna', 'hollow gonna', 'dollar gonna', 'roller gonna',
      'බලාගෙන', 'බලන්', 'බලාගෙනම', 'බලන්න'
    ],
    'sinhala_ehata_wenna_': [
      'ehata wenna', 'ehatawenna', 'ehata', 'ehaata wenna', 'ehata wena', 'ehaata',
      'move aside', 'move away', 'step back', 'get away', 'step aside',
      'a hata when now', 'a hata', 'a hot a winner', 'a hotter winner', 'a hata winner',
      'hotter winner', 'at the window', 'a tower now', 'out of window', 'a hata when',
      'ehata yanna',
      'එහාට වෙන්න', 'එහාටවෙන්න', 'එහාට', 'එහාට යන්න'
    ],
    'sinhala_parissamin_': [
      'parissamin', 'parisamin', 'parissamen', 'parisamen', 'parissam', 'parisam',
      'paris amin', 'be careful', 'take care', 'careful',
      'paris man', 'paris men', 'paris main', 'paris amen', 'paris sun', 'peris amin',
      'pari samin', 'pari samen', 'police man', 'police men',
      'පරිස්සමින්', 'පරිස්සමෙන්', 'පරිසමින්', 'පරිස්සම්', 'පරිස්සමෙන්ද'
    ],
  };

  // Environmental sound spoken keywords
  static const Map<String, List<String>> _envKeywords = {
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

    _isListening = true;
    _latestSoundVolume = 0.25;
    _keywordLockUntilMs = 0;
    _currentDisplayedKeyword = null;

    _startVisualizerTicker();

    // Start native Android Speech Recognizer (Uncontested mic access for real-time word-by-word streaming)
    _startSpeechRecognizer();

    _setSttStatus('Listening for speech… Say any word or emergency keyword.');
    return true;
  }

  void _startSpeechRecognizer() {
    try {
      _speechSubscription?.cancel();
      _speechSubscription = _speechEvents.receiveBroadcastStream().listen(
        (event) {
          if (!_isListening || event is! Map) return;
          final type = (event['type'] ?? '').toString();

          if (type == 'rms') {
            final double rmsVal = ((event['rms'] as num?)?.toDouble() ?? -2.0);
            final double vol =
                (0.20 + (rmsVal.clamp(-2.0, 10.0) / 10.0)).clamp(0.18, 1.0);
            _updateWaveformVolume(vol);
          } else if (type == 'partialResult' || type == 'finalResult') {
            final text = (event['text'] ?? '').toString().trim();
            final candidates = ((event['candidates'] as List?) ?? [])
                .map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .toList();

            if (text.isNotEmpty || candidates.isNotEmpty) {
              _processRecognizedSpeech(text, candidates);
            }
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );

      _speechChannel.invokeMethod('startListening').catchError((_) {});
    } catch (_) {}
  }

  String _clean(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s\u0D80-\u0DFF]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

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

  bool _matchesPattern(String target, String pattern) {
    if (target == pattern) return true;
    if (pattern.contains(' ')) {
      // Multi-word phrase: match anywhere in string
      if (target.contains(pattern)) return true;
    } else {
      // Single-word pattern: match word tokens or boundary
      final tokens = target.split(' ');
      for (final token in tokens) {
        if (token == pattern) return true;
        if (pattern.length >= 4 && token.length >= 4) {
          if (_levenshtein(token, pattern) <= 1) return true;
        }
      }
    }
    return false;
  }

  void _processRecognizedSpeech(String mainText, List<String> candidates) {
    final displayText = mainText.isNotEmpty ? mainText : (candidates.isNotEmpty ? candidates.first : '');
    if (displayText.isEmpty) return;

    final allHypotheses = [mainText, ...candidates]
        .map(_clean)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // === 1. MATCH AGAINST THE 8 SINHALA EMERGENCY KEYWORDS ===
    for (final hypothesis in allHypotheses) {
      for (final entry in _sinhalaKeywords.entries) {
        final soundKey = entry.key;
        for (final pattern in entry.value) {
          if (_matchesPattern(hypothesis, pattern)) {
            // Check if active alert lock is in effect
            if (nowMs < _keywordLockUntilMs && soundKey != _currentDisplayedKeyword) {
              return;
            }

            final previous = _lastKeywordTriggerTimes[soundKey];
            if (previous != null && nowMs - previous.millisecondsSinceEpoch < 1500) {
              return;
            }

            _lastKeywordTriggerTimes[soundKey] = DateTime.fromMillisecondsSinceEpoch(nowMs);
            _keywordLockUntilMs = nowMs + 2200; // Hold card for 2.2s so user can test next word easily
            _currentDisplayedKeyword = soundKey;

            // 1. Display formatted keyword in Live Speech box
            final formatted = _sinhalaLiveSpeechDisplay[soundKey] ?? displayText;
            _transcriptController.add(formatted);

            // 2. Pop up ONLY that matching emergency alert card!
            unawaited(simulateSoundDetection(
              soundKey,
              confidence: 0.99,
              overrideCooldown: true,
            ));
            return;
          }
        }
      }
    }

    // === 2. MATCH AGAINST SPOKEN ENVIRONMENTAL KEYWORDS ===
    if (nowMs >= _keywordLockUntilMs) {
      for (final hypothesis in allHypotheses) {
        for (final entry in _envKeywords.entries) {
          final envKey = entry.key;
          for (final pattern in entry.value) {
            if (_matchesPattern(hypothesis, pattern)) {
              final lastTime = _lastSoundAlertTimes[envKey];
              if (lastTime == null || nowMs - lastTime.millisecondsSinceEpoch >= 2500) {
                _lastSoundAlertTimes[envKey] = DateTime.fromMillisecondsSinceEpoch(nowMs);
                simulateSoundDetection(envKey, confidence: 0.95);
                return;
              }
            }
          }
        }
      }
    }

    // === 3. NORMAL CONVERSATIONAL SPEECH (FULL SENTENCES & WORDS) ===
    // Every spoken word or sentence displays word-by-word into Live Speech box!
    // ZERO alert cards pop up!
    _transcriptController.add(displayText);
  }

  void stopListening() {
    _isListening = false;
    _visualizerTicker?.cancel();
    _visualizerTicker = null;
    _latestSoundVolume = 0.02;
    _waveformController.add([]);
    _currentDisplayedKeyword = null;

    _speechSubscription?.cancel();
    _speechSubscription = null;
    try {
      _speechChannel.invokeMethod('stopListening');
    } catch (_) {}
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
