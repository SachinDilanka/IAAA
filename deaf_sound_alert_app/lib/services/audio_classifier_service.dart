import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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

  // Fallback speech-to-text plugin
  final stt.SpeechToText _speechFallback = stt.SpeechToText();
  bool _speechFallbackAvailable = false;
  Timer? _sttWatchdogTimer;

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

  // Exact Live Speech display strings for 6 Environmental sounds
  static const Map<String, String> _envLiveSpeechDisplay = {
    'ambulance': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
    'fire_truck': 'ගිනි නිවන රථ ශබ්දය (Fire Truck Siren)',
    'vehicle horns': 'වාහන හෝන් (Vehicle Horn)',
    'baby crying': 'ළදරුවාගේ හැඬීම (Baby Crying)',
    'dog_bark_dataset': 'බල්ලා බුරන හඬ (Dog Barking)',
    'traffic': 'මාර්ග තදබදය (Traffic Noise)',
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

    // 1. Start Native Android Speech Recognition for lively word-by-word Live Speech & Sinhala detection
    await _startSpeechRecognition();

    // 2. Start Hardware Audio Capture for Real-time Waveform & Background Environmental Sounds
    await _startAudioCapture();

    _setSttStatus('Listening lively. Say any word, sentence, or emergency keyword.');
    return true;
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
              _lastSpeechTimeMs = DateTime.now().millisecondsSinceEpoch;
              // 1. Lively display what the user is saying in real-time in the Live Speech box!
              _transcriptController.add(text);
              // 2. Evaluate for Sinhala emergency keywords
              _processSpeechText(text, candidates: candidates);
            }
          }
        },
        onError: (err) {
          // If native channel has an issue, fallback to speech_to_text plugin
          _startSpeechFallback();
        },
        cancelOnError: false,
      );

      final available =
          await _speechChannel.invokeMethod<bool>('isAvailable') ?? false;
      if (available) {
        await _speechChannel.invokeMethod('startListening');
      } else {
        await _startSpeechFallback();
      }
    } catch (_) {
      await _startSpeechFallback();
    }
  }

  Future<void> _startSpeechFallback() async {
    try {
      if (!_speechFallbackAvailable) {
        _speechFallbackAvailable = await _speechFallback.initialize(
          onError: (_) {},
          onStatus: (status) {
            if ((status == 'done' || status == 'notListening') && _isListening) {
              _speechFallback.listen(
                onResult: (result) {
                  if (!_isListening) return;
                  final rawWords = result.recognizedWords.trim();
                  if (rawWords.isNotEmpty) {
                    _lastSpeechTimeMs = DateTime.now().millisecondsSinceEpoch;
                    _transcriptController.add(rawWords);
                    _processSpeechText(rawWords);
                  }
                },
                listenOptions: stt.SpeechListenOptions(
                  listenMode: stt.ListenMode.dictation,
                  partialResults: true,
                  cancelOnError: false,
                ),
              );
            }
          },
        );
      }
      if (_speechFallbackAvailable && _isListening) {
        await _speechFallback.listen(
          onResult: (result) {
            if (!_isListening) return;
            final rawWords = result.recognizedWords.trim();
            if (rawWords.isNotEmpty) {
              _lastSpeechTimeMs = DateTime.now().millisecondsSinceEpoch;
              _transcriptController.add(rawWords);
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
          ),
        );
      }
    } catch (_) {}
  }

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
      // Single-word pattern: match word tokens or close typos
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

    // === 1. CHECK FOR SINHALA EMERGENCY KEYWORDS ===
    for (final target in targets) {
      for (final entry in _sinhalaKeywords.entries) {
        final soundKey = entry.key;
        for (final pattern in entry.value) {
          if (_matchesPattern(target, pattern)) {
            // Check if card is currently locked by previous keyword alert
            if (nowMs < _keywordLockUntilMs &&
                soundKey != _currentDisplayedKeyword) {
              return;
            }

            final previous = _lastKeywordTriggerTimes[soundKey];
            if (previous != null &&
                nowMs - previous.millisecondsSinceEpoch < 1500) {
              return;
            }

            _lastKeywordTriggerTimes[soundKey] =
                DateTime.fromMillisecondsSinceEpoch(nowMs);
            _keywordLockUntilMs = nowMs + 4000; // Lock for 4.0s against any wrong sound
            _lastSpeechTimeMs = nowMs;
            _currentDisplayedKeyword = soundKey;

            // Format nicely in live speech box
            final displayString = _sinhalaLiveSpeechDisplay[soundKey] ?? rawText;
            final fullDisplay = (cleanMain.length > 20)
                ? '$rawText  →  $displayString'
                : displayString;
            _transcriptController.add(fullDisplay);

            // Pop up ONLY that matching Sinhala emergency card!
            unawaited(simulateSoundDetection(
              soundKey,
              confidence: 0.99,
              overrideCooldown: true,
            ));
            return; // DONE! User voice NEVER triggers environmental sounds!
          }
        }
      }
    }

    // === 2. CHECK FOR SPOKEN ENVIRONMENTAL SOUND KEYWORDS ===
    // Evaluated only when no Sinhala keyword lock is active
    if (nowMs >= _keywordLockUntilMs) {
      for (final target in targets) {
        for (final entry in _envKeywords.entries) {
          final envKey = entry.key;
          for (final pattern in entry.value) {
            if (_matchesPattern(target, pattern)) {
              final lastTime = _lastSoundAlertTimes[envKey];
              if (lastTime == null ||
                  nowMs - lastTime.millisecondsSinceEpoch >= 3000) {
                _lastSoundAlertTimes[envKey] =
                    DateTime.fromMillisecondsSinceEpoch(nowMs);
                final display = _envLiveSpeechDisplay[envKey] ?? rawText;
                _transcriptController.add(display);
                unawaited(simulateSoundDetection(envKey, confidence: 0.95));
                return;
              }
            }
          }
        }
      }
    }

    // === 3. NORMAL SPEECH (NON-EMERGENCY SENTENCES OR WORDS) ===
    // Displayed in real-time in the Live Speech box. ZERO alert cards pop up!
    // No automatic popups!
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

    const envSoundMap = {
      'ambulance_siren': 'ambulance',
      'fire_truck': 'fire_truck',
      'vehicle_horn': 'vehicle horns',
      'baby_crying': 'baby crying',
      'dog_barking': 'dog_bark_dataset',
      'background_traffic': 'traffic',
    };

    // Voice Activity Detection (VAD) - when someone is speaking, mark speech time
    if (maxAmp >= 0.045 || rms >= 0.010) {
      // Audio energy detected
    }

    final bool startupGraceOver = (nowMs - _listeningStartTimeMs >= 800);

    // === BACKGROUND ENVIRONMENTAL SOUNDS ONLY (WHEN USER IS NOT SPEAKING) ===
    // Strictly evaluated ONLY when user has been completely silent for >= 3.0s
    // AND keyword lock is not active!
    final bool userSpokeRecently = (nowMs - _lastSpeechTimeMs < 3000);
    final bool keywordActive = (nowMs < _keywordLockUntilMs);

    // NOTE: Sinhala emergency alert cards are NEVER triggered from PCM sliding window!
    // Sinhala emergency alert cards pop up STRICTLY when recognized in speech!

    if (_total16kPushed >= 8000 &&
        startupGraceOver &&
        !userSpokeRecently &&
        !keywordActive &&
        (nowMs - _lastMlTimeMs >= 160)) {
      _lastMlTimeMs = nowMs;

      final List<double> window16k = List<double>.filled(16000, 0.0);
      double windowMax = 0.0;
      for (int i = 0; i < 16000; i++) {
        final s = _rollingBuf16k[(_rollingIdx - 16000 + i + 16000) % 16000];
        window16k[i] = s;
        final absS = s.abs();
        if (absS > windowMax) windowMax = absS;
      }

      final bool hasRealEnergy = (windowMax >= 0.045 && rms >= 0.010);
      if (!hasRealEnergy) {
        _pendingEnvironmentSound = null;
        _pendingEnvironmentVotes = 0;
        return;
      }

      // Check DSP Acoustic Filter (Baby Crying, Ambulance Siren, Horn, Dog Barking, Traffic)
      final acousticMatch = _detectEnvironmentalAcousticSound(window16k, windowMax, rms);

      String? candidateSound = acousticMatch;
      double candidateProb = 0.95;

      if (candidateSound == null && _neuralClassifier.isLoaded) {
        final double gain = (0.50 / windowMax).clamp(1.0, 50.0);
        final List<double> normWindow = List<double>.filled(16000, 0.0);
        for (int i = 0; i < 16000; i++) {
          normWindow[i] = (window16k[i] * gain).clamp(-1.0, 1.0);
        }

        final pred = _neuralClassifier.predict(normWindow);
        if (pred != null) {
          final allP = pred.allProbabilities;
          String? topEnvClass;
          double topEnvProb = 0.0;
          for (final e in envSoundMap.keys) {
            final p = allP[e] ?? 0.0;
            if (p > topEnvProb) {
              topEnvProb = p;
              topEnvClass = e;
            }
          }

          if (topEnvClass != null) {
            const envThresholds = {
              'ambulance_siren': 0.60,
              'fire_truck': 0.70,
              'vehicle_horn': 0.55,
              'baby_crying': 0.55,
              'dog_barking': 0.55,
              'background_traffic': 0.80,
            };
            final double reqProb = envThresholds[topEnvClass] ?? 0.60;
            if (topEnvProb >= reqProb) {
              candidateSound = envSoundMap[topEnvClass];
              candidateProb = topEnvProb;
            }
          }
        }
      }

      if (candidateSound != null) {
        final lastAlert = _lastSoundAlertTimes[candidateSound];
        final bool cooldownPassed = lastAlert == null ||
            nowMs - lastAlert.millisecondsSinceEpoch >= 3000;

        if (_pendingEnvironmentSound == candidateSound) {
          _pendingEnvironmentVotes++;
        } else {
          _pendingEnvironmentSound = candidateSound;
          _pendingEnvironmentVotes = 1;
        }

        if (cooldownPassed && _pendingEnvironmentVotes >= 2) {
          _lastSoundAlertTimes[candidateSound] =
              DateTime.fromMillisecondsSinceEpoch(nowMs);
          final display =
              _envLiveSpeechDisplay[candidateSound] ?? candidateSound;
          _transcriptController.add(display);
          simulateSoundDetection(candidateSound, confidence: candidateProb);
          _pendingEnvironmentVotes = 0;
          _pendingEnvironmentSound = null;
        }
      } else {
        _pendingEnvironmentSound = null;
        _pendingEnvironmentVotes = 0;
      }
    }
  }

  String? _detectEnvironmentalAcousticSound(
      List<double> window16k, double maxA, double rms) {
    if (window16k.length < 8000 || rms < 0.02 || maxA < 0.08) return null;

    final int n = window16k.length;
    int zcCount = 0;
    for (int i = 1; i < n; i++) {
      if ((window16k[i] >= 0 && window16k[i - 1] < 0) ||
          (window16k[i] < 0 && window16k[i - 1] >= 0)) {
        zcCount++;
      }
    }
    final double zcr = zcCount / n;

    final centerStart = (n ~/ 2) - 2048;
    const testN = 4096;

    double energyAt(double freq) {
      final double k = (freq * testN / 16000).roundToDouble();
      final double omega = (2.0 * math.pi / testN) * k;
      final double coeff = 2.0 * math.cos(omega);
      double q1 = 0.0, q2 = 0.0;

      for (int i = centerStart; i < centerStart + testN; i++) {
        final double q0 = coeff * q1 - q2 + window16k[i];
        q2 = q1;
        q1 = q0;
      }
      return q1 * q1 + q2 * q2 - q1 * q2 * coeff;
    }

    final double eLow =
        energyAt(100) + energyAt(150) + energyAt(200) + energyAt(250);
    final double eHorn = energyAt(380) + energyAt(440) + energyAt(500);
    final double eTruck = energyAt(300) + energyAt(550) + energyAt(650);
    final double eSiren =
        energyAt(750) + energyAt(850) + energyAt(950) + energyAt(1050);
    final double eCry =
        energyAt(1300) + energyAt(1600) + energyAt(2000) + energyAt(2400);
    final double eBark = energyAt(900) + energyAt(1200) + energyAt(1700);

    final double eTotal = eLow + eHorn + eTruck + eSiren + eCry + 1e-12;
    final double rLow = eLow / eTotal;
    final double rHorn = eHorn / eTotal;
    final double rSiren = eSiren / eTotal;
    final double rCry = eCry / eTotal;

    // Transient bursts check for dog barking
    int subFramesWithSpikes = 0;
    const subLen = 1600;
    for (int sf = 0; sf < 10; sf++) {
      double sfMax = 0.0;
      for (int i = sf * subLen; i < (sf + 1) * subLen; i++) {
        final a = window16k[i].abs();
        if (a > sfMax) sfMax = a;
      }
      if (sfMax > maxA * 0.70) subFramesWithSpikes++;
    }
    final bool isTransientBurst =
        (subFramesWithSpikes >= 1 && subFramesWithSpikes <= 4);

    // 1. Baby Crying: High-pitch infant vocal cry in 1300-2400 Hz
    if (rCry > 0.35 && zcr > 0.08 && rLow < 0.30) {
      return 'baby crying';
    }

    // 2. Ambulance Siren: Sweeping siren in 750-1050 Hz
    if (rSiren > 0.35 && rLow < 0.25 && !isTransientBurst) {
      return 'ambulance';
    }

    // 3. Vehicle Horn: 380-500 Hz chord blast
    if (rHorn > 0.45 && rLow < 0.30) {
      return 'vehicle horns';
    }

    // 4. Dog Barking: Short acoustic bursts
    if (isTransientBurst && zcr > 0.07 && (eBark / eTotal) > 0.30) {
      return 'dog_bark_dataset';
    }

    // 5. Traffic Noise: Low engine rumble
    if (rLow > 0.60 && zcr < 0.06) {
      return 'traffic';
    }

    // 6. Fire Truck Siren
    if ((eTruck / eTotal) > 0.60 && rLow < 0.30 && rCry < 0.15) {
      return 'fire_truck';
    }

    return null;
  }

  void stopListening() {
    _isListening = false;
    _visualizerTicker?.cancel();
    _visualizerTicker = null;
    _sttWatchdogTimer?.cancel();
    _sttWatchdogTimer = null;
    _speechSubscription?.cancel();
    _speechSubscription = null;
    try {
      _speechChannel.invokeMethod('stopListening');
    } catch (_) {}
    try {
      _speechFallback.stop();
    } catch (_) {}

    _latestSoundVolume = 0.02;
    _waveformController.add([]);
    _currentDisplayedKeyword = null;
    _pendingEnvironmentSound = null;
    _pendingEnvironmentVotes = 0;

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
