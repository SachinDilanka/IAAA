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
  int _keywordLockUntilMs = 0;
  String? _currentDisplayedKeyword;

  // Environmental detection voting
  String? _pendingEnvClass;
  int _pendingEnvVotes = 0;

  // Utterance accumulator for Sinhala emergency keywords (near & far voice)
  int _speechFramesCount = 0;
  int _speechSilenceFrames = 0;
  final Map<String, double> _speechSumProbs = {};
  final Map<String, double> _speechMaxProbs = {};
  final Map<String, int> _speechVotes = {};
  final Map<String, double> _envSumProbs = {};

  void _resetSpeechAccumulator() {
    _speechFramesCount = 0;
    _speechSilenceFrames = 0;
    _speechSumProbs.clear();
    _speechMaxProbs.clear();
    _speechVotes.clear();
    _envSumProbs.clear();
  }

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

  // Exact Live Speech display strings for Environmental sounds
  static const Map<String, String> _envLiveSpeechDisplay = {
    'ambulance': 'ambulance  →  ගිලන් රථ සයිරන් (Ambulance Siren)',
    'fire_truck': 'fire truck  →  ගිනි නිවන රථ ශබ්දය (Fire Truck Siren)',
    'vehicle horns': 'vehicle horn  →  වාහන හෝන් (Vehicle Horn)',
    'baby crying': 'baby crying  →  ළදරුවාගේ හැඬීම (Baby Crying)',
    'dog_bark_dataset': 'dog barking  →  බල්ලා බුරන හඬ (Dog Barking)',
  };

  // Comprehensive speech recognition patterns for all 8 Sinhala emergency keywords
  // Covers Sinhala unicode, Romanized spellings, phonetic transcriptions, and English equivalents
  static const Map<String, List<String>> _sinhalaKeywords = {
    'sinhala_udaw_': [
      'udaw', 'udau', 'udav', 'udaaw', 'udaav', 'uda', 'help', 'sos', 'emergency',
      'wood owl', 'woodowl', 'you dow', 'ooh dow', 'who dow', 'you down', 'u down', 'u dow',
      'you do', 'who do', 'you dive', 'you dial', 'you dough', 'you know', 'you have',
      'you doll', 'you dumb', 'you dao', 'out down', 'how do', 'hudaw', 'hudau', 'oo dow',
      'udo', 'dow', 'dao', 'you d have', 'you d how',
      'උදව්', 'උදවු', 'උදව්ව', 'උදව් කරන්න', 'උදව්වක්', 'උදව්ක්'
    ],
    'sinhala_karadarayak_': [
      'karadarayak', 'karadrayak', 'karadara', 'karadarai', 'karadarak', 'karadare', 'karadhara',
      'kara darayak', 'karadara yak', 'trouble', 'problem', 'distress',
      'kara da rai', 'kara da rak', 'car the rack', 'cardiac', 'car direct', 'care direct',
      'color dark', 'car dark', 'color direct', 'current direct', 'character', 'canada act',
      'car door act', 'corridor act', 'corridor', 'car the act', 'card direct', 'car react',
      'can direct',
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
      'balagene', 'bala gone', 'watch out', 'look out', 'caution',
      'bala gonna', 'ballerina', 'baller gonna', 'body gonna', 'bottle gonna',
      'by la gonna', 'follow gonna', 'hollow gonna', 'dollar gonna', 'roller gonna',
      'බලාගෙන', 'බලන්', 'බලාගෙනම', 'බලන්න'
    ],
    'sinhala_ehata_wenna_': [
      'ehata wenna', 'ehaata wenna', 'ehata', 'ehaata', 'ehatawenna', 'ehaatawenna',
      'move aside', 'clear way', 'get back', 'step aside', 'ehata venna',
      'a heart a winner', 'a hat a winner', 'hate a winner', 'a heart to winner',
      'heart to winner', 'hat a winner', 'a hard to winner', 'a hat of winner',
      'එහාට වෙන්න', 'එහාට', 'අහකට වෙන්න', 'අහකට'
    ],
    'sinhala_parissamin_': [
      'parissamin', 'parissamen', 'parissama', 'parissaming', 'parisamin',
      'be careful', 'take care', 'safe', 'safety', 'careful',
      'paris a men', 'paris salmon', 'paris amen', 'paris in', 'paris men',
      'perry sound', 'paris some', 'paris',
      'පරිස්සමින්', 'පරිස්සමෙන්', 'පරිස්සම්', 'පරිස්සමට'
    ],
  };

  static const Map<String, List<String>> _envKeywords = {
    'ambulance': ['ambulance', 'siren', 'emergency vehicle', 'ගිලන් රථ', 'ගිලන්රථ'],
    'fire_truck': ['fire truck', 'fire engine', 'fire brigade', 'ගිනි නිවන'],
    'vehicle horns': ['horn', 'honk', 'beep', 'car horn', 'vehicle horn', 'හෝන්'],
    'baby crying': ['baby crying', 'crying', 'baby cry', 'ළදරුවාගේ හැඬීම', 'අඬනවා'],
    'dog_bark_dataset': ['dog barking', 'barking', 'dog bark', 'බුරනවා', 'බල්ලා'],
  };

  final Map<String, DateTime> _lastKeywordTriggerTimes = {};

  String _normalizeText(String s) => s
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
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[s2.length];
  }

  bool _matchesPattern(String target, String pattern) {
    if (target == pattern) return true;
    if (pattern.contains(' ')) {
      if (target.contains(pattern)) return true;
    } else {
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

  void processSpeechText(String rawText, {List<String> candidates = const []}) {
    final cleanMain = _normalizeText(rawText);
    if (cleanMain.isEmpty) return;

    final targets = [cleanMain, ...candidates.map(_normalizeText)]
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // 1. Check for Sinhala emergency keywords
    for (final target in targets) {
      for (final entry in _sinhalaKeywords.entries) {
        final soundKey = entry.key;
        for (final pattern in entry.value) {
          if (_matchesPattern(target, pattern)) {
            if (nowMs < _keywordLockUntilMs && soundKey != _currentDisplayedKeyword) {
              return;
            }

            final previous = _lastKeywordTriggerTimes[soundKey];
            if (previous != null && nowMs - previous.millisecondsSinceEpoch < 1500) {
              return;
            }

            _lastKeywordTriggerTimes[soundKey] = DateTime.fromMillisecondsSinceEpoch(nowMs);
            _keywordLockUntilMs = nowMs + 1800;
            _currentDisplayedKeyword = soundKey;
            _resetSpeechAccumulator();
            _pendingEnvClass = null;
            _pendingEnvVotes = 0;

            // Formatted keyword in Live Speech box (e.g. udaw  →  උදව් (Udaw - Help))
            final displayString = _sinhalaLiveSpeechDisplay[soundKey] ?? rawText;
            _transcriptController.add(displayString);

            // Pop up ONLY that matching emergency alert card!
            unawaited(simulateSoundDetection(soundKey, confidence: 0.99, overrideCooldown: true));
            return;
          }
        }
      }
    }

    // 2. Check for Environmental keywords spoken
    for (final target in targets) {
      for (final entry in _envKeywords.entries) {
        final envKey = entry.key;
        for (final pattern in entry.value) {
          if (_matchesPattern(target, pattern)) {
            final lastTime = _lastSoundAlertTimes[envKey];
            if (lastTime == null || nowMs - lastTime.millisecondsSinceEpoch >= 2500) {
              _lastSoundAlertTimes[envKey] = DateTime.fromMillisecondsSinceEpoch(nowMs);
              final display = _envLiveSpeechDisplay[envKey] ?? rawText;
              _transcriptController.add(display);
              unawaited(simulateSoundDetection(envKey, confidence: 0.95));
              return;
            }
          }
        }
      }
    }

    // 3. Normal conversational words or sentences:
    // Displayed in real-time in the Live Speech box with ZERO alert card popups!
    _transcriptController.add(rawText);
  }


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
    _keywordLockUntilMs = 0;
    _rollingIdx = 0;
    _total16kPushed = 0;
    _lastMlTimeMs = 0;
    _pendingEnvClass = null;
    _pendingEnvVotes = 0;
    _resetSpeechAccumulator();
    _currentDisplayedKeyword = null;
    _latestSoundVolume = 0.25;
    _rollingBuf16k.fillRange(0, 16000, 0.0);

    _startVisualizerTicker();

    // 1. Start native Android Speech Recognizer for real-time word-by-word streaming & keyword recognition
    _startSpeechRecognition();

    // 2. Start continuous hardware audio capture for visualizer & neural sound classification
    await _startAudioCapture();

    _setSttStatus('Listening lively. Say any Sinhala word or emergency keyword.');
    return true;
  }

  void _startSpeechRecognition() {
    try {
      _speechSubscription?.cancel();
      _speechSubscription = _speechEvents.receiveBroadcastStream().listen(
        (event) {
          if (!_isListening || event is! Map) return;
          final type = (event['type'] ?? '').toString();
          if (type == 'rms') {
            final double rmsVal =
                ((event['rms'] as num?)?.toDouble() ?? -2.0);
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
              processSpeechText(text, candidates: candidates);
            }
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );

      _speechChannel.invokeMethod('startListening').catchError((_) {});
    } catch (_) {}
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

    // Run Neural Inference every 135ms on 16k window (after initial buffer fill)
    if (_total16kPushed >= 16000 &&
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

      // If alert lockout is currently active, hold
      if (nowMs < _keywordLockUntilMs) {
        _resetSpeechAccumulator();
        _pendingEnvClass = null;
        _pendingEnvVotes = 0;
        return;
      }

      // 1. Noise floor / silence gate: if room is quiet or low ambient noise, do not amplify or trigger
      if (windowMax < 0.045 && rms < 0.010) {
        if (_speechFramesCount > 0) {
          _speechSilenceFrames++;
          if (_speechSilenceFrames >= 2) {
            _checkAndTriggerOffsetSpeech(nowMs);
          }
        } else {
          _pendingEnvClass = null;
          _pendingEnvVotes = 0;
        }
        return;
      }

      // Smooth AGC: only boost active signals, up to 4.0x (prevents amplifying room hiss into fake alerts)
      final double gain = (windowMax >= 0.04) ? (0.55 / windowMax).clamp(1.0, 4.0) : 1.0;
      final List<double> normWindow = List<double>.filled(16000, 0.0);
      for (int i = 0; i < 16000; i++) {
        normWindow[i] = (window16k[i] * gain).clamp(-1.0, 1.0);
      }

      final pred = _neuralClassifier.predict(normWindow);
      if (pred == null) return;
      final allP = pred.allProbabilities;

      // Top speech probability
      double topSpeechProb = 0.0;
      for (final s in speechClasses) {
        final p = allP[s] ?? 0.0;
        if (p > topSpeechProb) {
          topSpeechProb = p;
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

      final double totalSpeechProb =
          speechClasses.fold(0.0, (sum, c) => sum + (allP[c] ?? 0.0));
      final double bgTrafficProb = allP['background_traffic'] ?? 0.0;

      // === 1. SPEECH INHIBITION & ACCUMULATION (All 8 Sinhala Emergency Keywords & Voice) ===
      // If voice or speech energy is present, human is vocalizing or speaking.
      // ENVIRONMENTAL SOUNDS MUST NEVER TRIGGER DURING HUMAN SPEECH!
      final bool isSpeechOrVoice = (windowMax >= 0.045 || rms >= 0.010) &&
          (totalSpeechProb >= 0.18 || topSpeechProb >= 0.20 || totalSpeechProb > topEnvProb);

      if (isSpeechOrVoice) {
        _pendingEnvClass = null;
        _pendingEnvVotes = 0;
        _speechSilenceFrames = 0;
        _speechFramesCount++;

        for (final s in speechClasses) {
          final p = allP[s] ?? 0.0;
          _speechSumProbs[s] = (_speechSumProbs[s] ?? 0.0) + p;
          if (p > (_speechMaxProbs[s] ?? 0.0)) {
            _speechMaxProbs[s] = p;
          }
          if (p >= 0.35) {
            _speechVotes[s] = (_speechVotes[s] ?? 0) + 1;
          }
        }

        for (final e in _envClassToSoundKey.keys) {
          final ep = allP[e] ?? 0.0;
          _envSumProbs[e] = (_envSumProbs[e] ?? 0.0) + ep;
        }

        if (_speechFramesCount == 1 && nowMs > _keywordLockUntilMs) {
          _transcriptController.add('Speaking Sinhala Voice...');
        }
        return;
      }

      // Voice dropped / speech offset (user finished saying word "just one time")
      if (_speechFramesCount > 0) {
        _speechSilenceFrames++;
        // 2 consecutive non-speech frames (~270ms) means the single utterance has ended
        if (_speechSilenceFrames >= 2) {
          _checkAndTriggerOffsetSpeech(nowMs);
          return;
        }
      }

      // === 2. REAL ENVIRONMENTAL EMERGENCY SOUNDS (Baby Crying, Dog Barking, Vehicle Horn, Fire Truck, Ambulance, Traffic) ===
      // Can ONLY trigger when there is ABSOLUTELY NO HUMAN SPEECH (totalSpeechProb < 0.10 and topSpeechProb < 0.10)
      if (totalSpeechProb < 0.10 && topSpeechProb < 0.10) {
        // Traffic noises: loud continuous road traffic sound
        if (windowMax >= 0.20 && rms >= 0.035 && bgTrafficProb >= 0.88) {
          final lastAlert = _lastSoundAlertTimes['traffic'];
          final bool cooldownPassed = lastAlert == null ||
              nowMs - lastAlert.millisecondsSinceEpoch >= 2500;

          if (_pendingEnvClass == 'traffic') {
            _pendingEnvVotes++;
          } else {
            _pendingEnvClass = 'traffic';
            _pendingEnvVotes = 1;
          }

          if (cooldownPassed && _pendingEnvVotes >= 5) {
            _lastSoundAlertTimes['traffic'] = DateTime.fromMillisecondsSinceEpoch(nowMs);
            _keywordLockUntilMs = nowMs + 2000;
            _pendingEnvVotes = 0;
            _pendingEnvClass = null;
            _resetSpeechAccumulator();

            final envDisplay = _envLiveSpeechDisplay['traffic'] ?? 'traffic noise  →  වාහන තදබදය (Traffic Noise)';
            _transcriptController.add(envDisplay);
            simulateSoundDetection('traffic', confidence: 0.95, overrideCooldown: true);
            return;
          }
        }

        // Siren / Horn / Baby Crying / Dog Barking
        // Must be genuinely loud, sustained for >= 4 confirmation frames (~540ms), and dominate traffic
        if (topEnvClass != null &&
            windowMax >= 0.08 && rms >= 0.018 &&
            topEnvProb >= 0.75 &&
            topEnvProb > bgTrafficProb) {
          final candidateSound = _envClassToSoundKey[topEnvClass];
          if (candidateSound != null) {
            final lastAlert = _lastSoundAlertTimes[candidateSound];
            final bool cooldownPassed = lastAlert == null ||
                nowMs - lastAlert.millisecondsSinceEpoch >= 2500;

            if (_pendingEnvClass == candidateSound) {
              _pendingEnvVotes++;
            } else {
              _pendingEnvClass = candidateSound;
              _pendingEnvVotes = 1;
            }

            // Real environmental emergency sounds require 4 consecutive confirmed frames (~540ms)
            if (cooldownPassed && _pendingEnvVotes >= 4) {
              _lastSoundAlertTimes[candidateSound] =
                  DateTime.fromMillisecondsSinceEpoch(nowMs);
              _keywordLockUntilMs = nowMs + 1800;
              _pendingEnvVotes = 0;
              _pendingEnvClass = null;
              _resetSpeechAccumulator();

              // 1. Display in Live Speech box with full English and Sinhala text
              final envDisplay = _envLiveSpeechDisplay[candidateSound] ?? candidateSound;
              _transcriptController.add(envDisplay);

              // 2. Pop up suitable environmental alert card
              simulateSoundDetection(
                candidateSound,
                confidence: math.max(topEnvProb, 0.95),
                overrideCooldown: true,
              );
              return;
            }
          }
        } else {
          _pendingEnvClass = null;
          _pendingEnvVotes = 0;
        }
      } else {
        _pendingEnvClass = null;
        _pendingEnvVotes = 0;
      }
    }
  }

  void _checkAndTriggerOffsetSpeech(int nowMs) {
    if (_speechFramesCount >= 1 && nowMs >= _keywordLockUntilMs) {
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
      String bestCandidate = speechClasses.first;
      double bestSum = 0.0;
      for (final s in speechClasses) {
        final sSum = _speechSumProbs[s] ?? 0.0;
        if (sSum > bestSum) {
          bestSum = sSum;
          bestCandidate = s;
        }
      }
      final double bestPeak = _speechMaxProbs[bestCandidate] ?? 0.0;
      final int bestVotes = _speechVotes[bestCandidate] ?? 0;

      double secondSum = 0.0;
      for (final s in speechClasses) {
        if (s != bestCandidate) {
          final sSum = _speechSumProbs[s] ?? 0.0;
          if (sSum > secondSum) secondSum = sSum;
        }
      }

      double bestEnvSum = 0.0;
      for (final e in _envClassToSoundKey.keys) {
        final es = _envSumProbs[e] ?? 0.0;
        if (es > bestEnvSum) bestEnvSum = es;
      }

      // Identify whether user spoke one of the 8 Sinhala emergency keywords:
      final bool isDominantKeyword = (bestVotes >= 2) &&
          (bestPeak >= 0.45 && bestSum >= 0.85) &&
          (bestSum > bestEnvSum) &&
          ((secondSum == 0.0) || (bestSum >= secondSum * 1.25));

      if (isDominantKeyword) {
        _triggerKeywordAlert(bestCandidate, bestPeak, nowMs);
        return;
      } else if (_speechFramesCount >= 2) {
        // Normal conversational speech: User said normal words or conversational sentence
        _transcriptController.add('Voice Heard (Normal Conversational Speech)');
      }
    }
    _resetSpeechAccumulator();
  }

  void _triggerKeywordAlert(String speechClass, double confidence, int nowMs) {
    final soundKey = _classToSoundKey[speechClass];
    if (soundKey == null) return;

    _keywordLockUntilMs = nowMs + 1500; // Hold for 1.5s so user can test next word sequentially
    _currentDisplayedKeyword = soundKey;
    _resetSpeechAccumulator();
    _pendingEnvClass = null;
    _pendingEnvVotes = 0;

    // 1. Immediately display in Live Speech box with full English and Sinhala text
    final displayText = _sinhalaLiveSpeechDisplay[soundKey] ?? speechClass;
    _transcriptController.add(displayText);

    // 2. Pop up ONLY that matching emergency alert card!
    unawaited(simulateSoundDetection(
      soundKey,
      confidence: math.max(confidence, 0.98),
      overrideCooldown: true,
    ));
  }

  void stopListening() {
    _isListening = false;
    _visualizerTicker?.cancel();
    _visualizerTicker = null;

    _speechSubscription?.cancel();
    _speechSubscription = null;
    try {
      _speechChannel.invokeMethod('stopListening');
    } catch (_) {}

    _latestSoundVolume = 0.02;
    _waveformController.add([]);
    _currentDisplayedKeyword = null;
    _pendingEnvClass = null;
    _pendingEnvVotes = 0;
    _resetSpeechAccumulator();

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

