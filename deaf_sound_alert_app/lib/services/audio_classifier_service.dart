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
  final Map<String, double> _speechSumProbs = {};
  final Map<String, double> _speechMaxProbs = {};

  void _resetSpeechAccumulator() {
    _speechFramesCount = 0;
    _speechSumProbs.clear();
    _speechMaxProbs.clear();
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
    'ambulance': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
    'fire_truck': 'ගිනි නිවන රථ ශබ්දය (Fire Truck Siren)',
    'vehicle horns': 'වාහන හෝන් (Vehicle Horn)',
    'baby crying': 'ළදරුවාගේ හැඬීම (Baby Crying)',
    'dog_bark_dataset': 'බල්ලා බුරන හඬ (Dog Barking)',
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
      'karadarayak', 'karadara', 'karadarai', 'karadarak', 'karadare', 'karadhara',
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

  void _processSpeechText(String rawText, {List<String> candidates = const []}) {
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
            _keywordLockUntilMs = nowMs + 2500;
            _currentDisplayedKeyword = soundKey;

            // Formatted keyword in Live Speech box
            final displayString = _sinhalaLiveSpeechDisplay[soundKey] ?? rawText;
            final fullDisplay = (cleanMain.length > 20)
                ? '$rawText  →  $displayString'
                : displayString;
            _transcriptController.add(fullDisplay);

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

  Future<void> _startSpeechRecognition() async {
    try {
      await _speechSubscription?.cancel();
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
          } else if ((type == 'partialResult' || type == 'finalResult')) {
            final text = (event['text'] ?? '').toString().trim();
            final candidates = ((event['candidates'] as List?) ?? [])
                .map((e) => e.toString())
                .toList();
            if (text.isNotEmpty) {
              _processSpeechText(text, candidates: candidates);
            }
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );

      final available =
          await _speechChannel.invokeMethod<bool>('isAvailable') ?? false;
      if (available) {
        await _speechChannel.invokeMethod('startListening');
      }
    } catch (_) {}
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

    // 1. Start Native Android Speech Recognition for live word-by-word Live Speech & Sinhala detection
    await _startSpeechRecognition();

    // 2. Start hardware audio capture for visualizer & background sound processing
    await _startAudioCapture();

    _setSttStatus('Listening lively. Say any Sinhala word, sentence, or emergency keyword.');
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

      // If alert lockout is currently active (2.2s after a keyword fired), hold
      if (nowMs < _keywordLockUntilMs) {
        _resetSpeechAccumulator();
        _pendingEnvClass = null;
        _pendingEnvVotes = 0;
        return;
      }

      // Silence floor check
      if (windowMax < 0.003) {
        _resetSpeechAccumulator();
        _pendingEnvClass = null;
        _pendingEnvVotes = 0;
        return;
      }

      // Gentle AGC: normalizes voice volume smoothly without creating high-frequency spectral artifacts
      final double gain = (0.35 / windowMax).clamp(1.0, 2.5);
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

      final double bgTrafficProb = allP['background_traffic'] ?? 0.0;
      final double totalSpeechProb =
          speechClasses.fold(0.0, (sum, c) => sum + (allP[c] ?? 0.0));
      final double totalEnvProb =
          _envClassToSoundKey.keys.fold(0.0, (sum, c) => sum + (allP[c] ?? 0.0));

      // === 1. ENVIRONMENTAL EMERGENCY SOUNDS (Baby Crying, Ambulance, Fire Truck, Horn, Dog Barking) ===
      if (topEnvClass != null &&
          totalEnvProb > totalSpeechProb * 1.5 &&
          totalEnvProb >= 0.65 &&
          totalSpeechProb < 0.20) {
        _resetSpeechAccumulator();

        final candidateSound = _envClassToSoundKey[topEnvClass];
        if (candidateSound != null) {
          final lastAlert = _lastSoundAlertTimes[candidateSound];
          final bool cooldownPassed = lastAlert == null ||
              nowMs - lastAlert.millisecondsSinceEpoch >= 2200;

          if (_pendingEnvClass == candidateSound && topEnvProb >= 0.65) {
            _pendingEnvVotes++;
          } else {
            _pendingEnvClass = candidateSound;
            _pendingEnvVotes = 1;
          }

          // Trigger on 2 confirmation frames (~270ms) or high instant confidence
          final bool shouldTriggerEnv =
              (topEnvProb >= 0.88) || (_pendingEnvVotes >= 2 && topEnvProb >= 0.70);
          if (cooldownPassed && shouldTriggerEnv) {
            _lastSoundAlertTimes[candidateSound] =
                DateTime.fromMillisecondsSinceEpoch(nowMs);
            simulateSoundDetection(candidateSound, confidence: topEnvProb);
            _keywordLockUntilMs = nowMs + 2200;
            _pendingEnvVotes = 0;
            _pendingEnvClass = null;
          }
        }
        return;
      }

      // === 2. ALL 8 SINHALA EMERGENCY KEYWORDS (NEAR & FAR VOICE) ===
      if (totalSpeechProb > totalEnvProb &&
          (totalSpeechProb >= 0.35 || topSpeechProb >= 0.40)) {
        _pendingEnvClass = null;
        _pendingEnvVotes = 0;
        _speechFramesCount++;

        for (final s in speechClasses) {
          final p = allP[s] ?? 0.0;
          _speechSumProbs[s] = (_speechSumProbs[s] ?? 0.0) + p;
          if (p > (_speechMaxProbs[s] ?? 0.0)) {
            _speechMaxProbs[s] = p;
          }
        }

        // Determine best speech candidate based on accumulated probabilities
        String bestCandidate = topSpeechClass;
        double bestSum = _speechSumProbs[bestCandidate] ?? 0.0;
        for (final s in speechClasses) {
          final sSum = _speechSumProbs[s] ?? 0.0;
          if (sSum > bestSum) {
            bestSum = sSum;
            bestCandidate = s;
          }
        }

        final double bestPeak = _speechMaxProbs[bestCandidate] ?? 0.0;

        // Utterance trigger conditions:
        // A) High-confidence trigger: 3 frames (~405ms) with peak >= 0.88 and dominant sum
        // B) Utterance completion trigger: 5-6 frames (~675-810ms, full human word length) with peak >= 0.60
        final bool shouldTriggerSpeech =
            (_speechFramesCount >= 3 && bestPeak >= 0.88 && bestSum >= 2.0) ||
            (_speechFramesCount >= 5 && bestPeak >= 0.60 && bestSum >= 2.2);

        if (shouldTriggerSpeech) {
          _triggerKeywordAlert(bestCandidate, bestPeak, nowMs);
          _resetSpeechAccumulator();
        }
        return;
      }

      // Background room silence / road noise check
      if (bgTrafficProb >= 0.70 && totalSpeechProb < 0.20) {
        _resetSpeechAccumulator();
        _pendingEnvClass = null;
        _pendingEnvVotes = 0;
        return;
      }

      _pendingEnvClass = null;
      _pendingEnvVotes = 0;
    }
  }

  void _triggerKeywordAlert(String speechClass, double confidence, int nowMs) {
    final soundKey = _classToSoundKey[speechClass];
    if (soundKey == null) return;

    _keywordLockUntilMs = nowMs + 2200; // Hold for 2.2s so user can test next word sequentially
    _currentDisplayedKeyword = soundKey;
    _resetSpeechAccumulator();
    _pendingEnvClass = null;
    _pendingEnvVotes = 0;

    // 1. Display formatted keyword in Live Speech box
    final displayText = _sinhalaLiveSpeechDisplay[soundKey] ?? speechClass;
    _transcriptController.add(displayText);

    // 2. Pop up ONLY that matching emergency alert card!
    unawaited(simulateSoundDetection(
      soundKey,
      confidence: math.max(confidence, 0.98),
      overrideCooldown: true,
    ));

    // Note: Do not fill buffer with zeros! Continuous microphone flow prevents artificial step artifacts.
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

