import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audio_streamer/audio_streamer.dart';
import 'audio_capture_interface.dart';
import 'native_neural_audio_classifier.dart';

AudioCaptureInterface getAudioCaptureBridge() => AudioCaptureNative();

/// Rebuilt High-Performance Mobile Acoustic AI & Live Sinhala Speech Engine
class AudioCaptureNative implements AudioCaptureInterface {
  final SpeechToText _speechToText = SpeechToText();
  final NativeNeuralAudioClassifier _classifier = NativeNeuralAudioClassifier();
  final math.Random _random = math.Random();
  StreamSubscription<List<double>>? _audioStreamSubscription;

  AudioCaptureNative() {
    _loadNeuralNetwork();
  }

  bool _isListening = false;
  bool _isSpeechInitialized = false;
  String _selectedLocaleId = 'si-LK';
  String _matchedLocaleId = 'si-LK';

  DateTime _lastTriggerTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSpeechTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _alertLatched = false;
  final Map<String, DateTime> _classCooldown = {};
  int _lastMlTime = 0;
  int _lastPcmTimeMs = 0;
  String _consecutiveClassLabel = '';
  int _consecutiveClassCount = 0;

  // Fixed 16,000 Hz circular buffer (1.0 second = 16,000 samples)
  final List<double> _rollingBuf16k = List<double>.filled(16000, 0.0);
  int _rollingIdx = 0;
  int _total16kPushed = 0;

  int _hardwareSampleRate = 16000;
  double _latestVolume = 0.08;
  int _latestPitch = 220;
  List<double> _latestFrame = List.generate(40, (i) => 0.08);
  String _latestTranscript = "🎤 AI Audio & Voice Monitor Standby...";
  Map<String, dynamic>? _latestAlert;

  Timer? _speechRestartTimer;
  Timer? _ambientWaveTimer;

  Function(List<double> frame, double volume, int peakFreq)? _onAudioFrame;
  Function(String detectedClass, double confidence, String source)? _onAudioEvent;
  Function(String transcript)? _onSpeechTranscript;

  static const Map<String, String?> flutterClassMap = {
    'udaw': 'udaw',
    'beeraganna': 'beeraganna',
    'ginnak': 'ginnak',
    'anathurak': 'anathurak',
    'karadarayak': 'karadarayak',
    'balagena': 'balagena',
    'parissamin': 'parissamin',
    'ehata_wenna': 'ehata_wenna',
    'ambulance_siren': 'ambulance',
    'ambulance': 'ambulance',
    'vehicle_horn': 'vehicle_horn',
    'vehicle horns': 'vehicle_horn',
    'baby_crying': 'baby_crying',
    'baby crying': 'baby_crying',
    'dog_barking': 'dog_barking',
    'dog_bark': 'dog_barking',
    'background_traffic': null,
  };

  static const Map<String, double> classThresholds = {
    'baby_crying': 0.90,
    'dog_barking': 0.90,
    'vehicle_horn': 0.90,
    'ambulance_siren': 0.90,
    'udaw': 0.35,
    'beeraganna': 0.35,
    'ginnak': 0.35,
    'anathurak': 0.35,
    'karadarayak': 0.35,
    'balagena': 0.35,
    'parissamin': 0.35,
    'ehata_wenna': 0.35,
  };

  static const Map<String, String> sinhalaTitles = {
    'udaw': 'උදව් කරන්න!',
    'beeraganna': 'බේරගන්න!',
    'ginnak': 'ගින්නක්!',
    'anathurak': 'අනතුරක්!',
    'karadarayak': 'කරදරයක්!',
    'balagena': 'බලාගෙන!',
    'parissamin': 'පරිස්සමින්!',
    'ehata_wenna': 'එහාට වෙන්න!',
    'ambulance': 'ගිලන් රථ සයිරන්',
    'ambulance_siren': 'ගිලන් රථ සයිරන්',
    'vehicle horns': 'වාහන හෝන්',
    'vehicle_horn': 'වාහන හෝන්',
    'baby crying': 'ළදරු හැඬීම',
    'baby_crying': 'ළදරු හැඬීම',
    'dog_bark': 'බල්ලා බිරීම',
    'dog_barking': 'බල්ලා බිරීම',
  };

  @override
  void startCapture({
    required Function(List<double> frame, double volume, int peakFreq) onAudioFrame,
    required Function(String detectedClass, double confidence, String source) onAudioEvent,
    required Function(String transcript) onSpeechTranscript,
  }) async {
    _isListening = true;
    _onAudioFrame = onAudioFrame;
    _onAudioEvent = onAudioEvent;
    _onSpeechTranscript = onSpeechTranscript;
    _total16kPushed = 0;
    _rollingIdx = 0;
    _alertLatched = false;

    // 1. Request Android Runtime Permissions
    try {
      final mic = await Permission.microphone.request();
      await [
        Permission.notification,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request();

      if (!mic.isGranted) {
        _latestTranscript = "⚠️ Microphone permission required. Please grant permission in Settings.";
        onSpeechTranscript(_latestTranscript);
        return;
      }
    } catch (e) {
      debugPrint('[AudioCaptureNative] Permission error: $e');
    }

    await _loadNeuralNetwork();
    _startAmbientWaveTicker();

    _latestTranscript = "🎤 Live Mic Active: Listening for Sinhala Voice & Environmental Sounds...";
    _onSpeechTranscript?.call(_latestTranscript);

    await _initAndStartSpeechRecognition();
    _startAudioStreamer();
  }

  Future<void> _loadNeuralNetwork() async {
    try {
      final ok = await _classifier.loadModel();
      debugPrint('[AudioCaptureNative] Neural Classifier loaded: $ok');
    } catch (e) {
      debugPrint('[AudioCaptureNative] Neural Classifier load error: $e');
    }
  }

  // =========================================================================
  // SPEECH RECOGNITION (CONTINUOUS LIVE TRANSCRIPT STREAM & SINHALA KEYWORDS)
  // =========================================================================

  Future<void> _initAndStartSpeechRecognition() async {
    if (!_isListening) return;

    try {
      if (!_isSpeechInitialized) {
        _isSpeechInitialized = await _speechToText.initialize(
          onStatus: (status) {
            debugPrint('[AudioCaptureNative STT Status]: $status');
            if (!_isListening) return;

            if (status == 'listening') {
              if (!_latestTranscript.startsWith('🗣️') &&
                  !_latestTranscript.startsWith('🚨') &&
                  !_latestTranscript.contains('Detected')) {
                _latestTranscript = "🎤 Live Mic Active: Listening for Sinhala Voice & Sounds...";
                _onSpeechTranscript?.call(_latestTranscript);
              }
            } else if (status == 'notListening' || status == 'done') {
              _scheduleSpeechRestart(delayMs: 200);
            }
          },
          onError: (errorNotification) {
            debugPrint('[AudioCaptureNative STT Error]: ${errorNotification.errorMsg}');
            if (!_isListening) return;
            final msg = errorNotification.errorMsg.toLowerCase();
            if (msg.contains('language') || msg.contains('locale') || msg.contains('not supported')) {
              _matchedLocaleId = 'en-US';
              _selectedLocaleId = 'en-US';
            }
            _scheduleSpeechRestart(delayMs: 800);
          },
        );

        try {
          final locales = await _speechToText.locales();
          final siMatch = locales.firstWhere(
            (l) => l.localeId.toLowerCase().startsWith('si'),
            orElse: () => locales.firstWhere(
              (l) => l.localeId.toLowerCase().startsWith('en'),
              orElse: () => locales.isNotEmpty ? locales.first : LocaleName('en-US', 'English'),
            ),
          );
          _matchedLocaleId = siMatch.localeId;
          debugPrint('[AudioCaptureNative] Best speech locale matched: $_matchedLocaleId');
        } catch (_) {
          _matchedLocaleId = 'si-LK';
        }
      }

      if (_isListening) {
        _startSpeechSession();
      }
    } catch (e) {
      debugPrint('[AudioCaptureNative] STT Init exception: $e');
      _scheduleSpeechRestart(delayMs: 600);
    }
  }

  void _startSpeechSession() async {
    if (!_isListening) return;

    try {
      final targetLocale = _selectedLocaleId.toLowerCase().startsWith('si')
          ? _matchedLocaleId
          : 'en-US';

      final options = SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: false,
        autoPunctuation: true,
        enableHapticFeedback: false,
        localeId: targetLocale,
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(seconds: 30),
      );

      if (_speechToText.isListening) return;

      await _speechToText.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            _lastSpeechTime = DateTime.now();
            final displayText = '🗣️ Live Voice: "$words"';
            _latestTranscript = displayText;
            _onSpeechTranscript?.call(displayText);
            _matchKeywords(words);
          }
        },
        listenOptions: options,
        onSoundLevelChange: (level) {
          _handleSoundLevel(level);
        },
      );
    } catch (e) {
      debugPrint('[AudioCaptureNative] STT listen error: $e');
      if (_matchedLocaleId != 'en-US') {
        _matchedLocaleId = 'en-US';
        _selectedLocaleId = 'en-US';
      }
      _scheduleSpeechRestart(delayMs: 400);
    }
  }

  void _scheduleSpeechRestart({int delayMs = 300}) {
    if (!_isListening) return;
    _speechRestartTimer?.cancel();
    _speechRestartTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (!_isListening) return;
      try {
        if (_speechToText.isListening) {
          await _speechToText.stop();
        }
      } catch (_) {}
      _startSpeechSession();
    });
  }

  void _stopSpeechRecognition() {
    _speechRestartTimer?.cancel();
    _speechRestartTimer = null;
    try {
      _speechToText.stop();
    } catch (_) {}
  }

  // =========================================================================
  // AUDIO STREAMER & NEURAL CLASSIFIER (40-MFCC DEEP MODEL)
  // =========================================================================

  void _startAudioStreamer() {
    if (!_isListening) return;

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
          debugPrint('[AudioCaptureNative] AudioStreamer error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[AudioCaptureNative] AudioStreamer init error: $e');
    }
  }

  Future<void> _stopAudioStreamer() async {
    try {
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
    } catch (_) {}
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

    if (_hardwareSampleRate <= 0) {
      if (rawBuffer.length >= 4096) {
        _hardwareSampleRate = 48000;
      } else if (rawBuffer.length >= 3528 || rawBuffer.length == 4410) {
        _hardwareSampleRate = 44100;
      } else {
        _hardwareSampleRate = 44100; // Default to standard 44.1 kHz on mobile
      }
    }

    double maxRaw = 0.0;
    for (int i = 0; i < rawBuffer.length; i++) {
      final a = rawBuffer[i].abs();
      if (a > maxRaw) maxRaw = a;
    }
    final double normScale = maxRaw > 2.0 ? (1.0 / 32768.0) : 1.0;

    List<double> packet16k;
    if (_hardwareSampleRate == 16000) {
      packet16k = List<double>.generate(rawBuffer.length, (i) => rawBuffer[i] * normScale);
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
          sum += rawBuffer[j] * normScale;
          count++;
        }
        packet16k[i] = count > 0 ? (sum / count) : (rawBuffer[startIdx.clamp(0, rawBuffer.length - 1)] * normScale);
      }
    }

    double sumSquares = 0.0;
    int zeroCrossings = 0;
    double maxAmp = 0.0;

    for (int i = 0; i < packet16k.length; i++) {
      final s = packet16k[i];
      final absS = s.abs();
      if (absS > maxAmp) maxAmp = absS;
      sumSquares += s * s;
      if (i > 0 && ((packet16k[i - 1] >= 0 && s < 0) || (packet16k[i - 1] < 0 && s >= 0))) {
        zeroCrossings++;
      }

      _rollingBuf16k[_rollingIdx] = s;
      _rollingIdx = (_rollingIdx + 1) % 16000;
      _total16kPushed++;
    }

    final rms = math.sqrt(sumSquares / packet16k.length);
    final double normalizedVol = (rms * 8.0).clamp(0.04, 1.0);

    final double durationSec = packet16k.length / 16000.0;
    double estimatedHz = 0.0;
    if (durationSec > 0) {
      estimatedHz = ((zeroCrossings / 2.0) / durationSec).clamp(60.0, 5000.0);
    }

    _latestVolume = normalizedVol;
    _latestPitch = estimatedHz.round();

    final centerBand = ((estimatedHz / 3500.0) * 40).clamp(2, 38).round();
    final List<double> frame = List<double>.generate(40, (i) {
      final dist = (i - centerBand).abs();
      final spread = math.exp(-dist * 0.18);
      final wave = math.sin((i * 0.3) + (DateTime.now().millisecondsSinceEpoch * 0.015)).abs() * 0.25;
      return (normalizedVol * (spread * 0.75 + wave + 0.1)).clamp(0.04, 1.0);
    });
    _latestFrame = frame;
    _onAudioFrame?.call(frame, _latestVolume, _latestPitch);

    // Run Neural Network Inference on 1-second rolling buffer
    final bool isSpeechActive = nowMs - _lastSpeechTime.millisecondsSinceEpoch < 2500;

    if (nowMs - _lastMlTime > 150 && _classifier.isLoaded && _total16kPushed >= 16000) {
      final List<double> window1s = List<double>.filled(16000, 0.0);
      double winSumSq = 0.0;
      double winMaxAmp = 0.0;
      for (int i = 0; i < 16000; i++) {
        final val = _rollingBuf16k[(_rollingIdx - 16000 + i + 16000) % 16000];
        window1s[i] = val;
        final absV = val.abs();
        if (absV > winMaxAmp) winMaxAmp = absV;
        winSumSq += val * val;
      }
      final winRms = math.sqrt(winSumSq / 16000.0);

      // Require real energy
      if (winRms >= 0.015 && winMaxAmp >= 0.030) {
        _lastMlTime = nowMs;
        final prediction = _classifier.predict(window1s);

        if (prediction != null) {
          final topClass = prediction.label;
          final topProb = prediction.probability;

          if (topClass == _consecutiveClassLabel) {
            _consecutiveClassCount++;
          } else {
            _consecutiveClassLabel = topClass;
            _consecutiveClassCount = 1;
          }

          final bool isSinhalaKeyword = (topClass == 'udaw' ||
              topClass == 'beeraganna' ||
              topClass == 'ginnak' ||
              topClass == 'anathurak' ||
              topClass == 'karadarayak' ||
              topClass == 'balagena' ||
              topClass == 'parissamin' ||
              topClass == 'ehata_wenna');

          final bool isEnvironmental = (topClass == 'ambulance_siren' ||
              topClass == 'vehicle_horn' ||
              topClass == 'baby_crying' ||
              topClass == 'dog_barking');

          if (isSinhalaKeyword && topProb >= 0.85 && _consecutiveClassCount >= 2) {
            _triggerMlAlert(topClass, topProb);
            _consecutiveClassCount = 0;
          } else if (isEnvironmental && topProb >= 0.94 && _consecutiveClassCount >= 4 && !isSpeechActive) {
            _triggerMlAlert(topClass, topProb);
            _consecutiveClassCount = 0;
          }
        }
      }
    }
  }

  void _triggerMlAlert(String rawCls, double confidence) {
    if (_alertLatched) return;

    final now = DateTime.now();
    final fc = flutterClassMap[rawCls];
    if (fc == null) return;

    if (now.difference(_lastTriggerTime).inMilliseconds < 1200) return;

    final lastClassTime = _classCooldown[fc];
    if (lastClassTime != null && now.difference(lastClassTime).inMilliseconds < 2200) {
      return;
    }

    _lastTriggerTime = now;
    _classCooldown[fc] = now;
    _alertLatched = true;

    Timer(const Duration(milliseconds: 2200), () {
      _alertLatched = false;
    });

    final sinhala = sinhalaTitles[fc] ?? fc;
    final source = "Acoustic AI Model: $rawCls (${(confidence * 100).toStringAsFixed(0)}%)";

    String emoji = "🚨";
    String titleText = "";
    if (fc.contains('baby')) {
      emoji = "👶";
    } else if (fc.contains('dog')) {
      emoji = "🐕";
    } else if (fc.contains('horn')) {
      emoji = "🚗";
    } else if (fc.contains('ambulance')) {
      emoji = "🚑";
    }

    // Update live transcript box if a Sinhala keyword was detected by acoustic model
    if (fc == 'udaw' ||
        fc == 'beeraganna' ||
        fc == 'ginnak' ||
        fc == 'anathurak' ||
        fc == 'karadarayak' ||
        fc == 'balagena' ||
        fc == 'parissamin' ||
        fc == 'ehata_wenna') {
      final displayText = '🗣️ Live Voice (AI Keyword): "$rawCls ($sinhala)"';
      _latestTranscript = displayText;
      _onSpeechTranscript?.call(displayText);
    }

    _latestAlert = {
      'category': fc,
      'confidence': confidence,
      'source': source,
      'timestamp': now.millisecondsSinceEpoch,
    };

    debugPrint('[AudioCaptureNative Acoustic Alert Triggered]: $fc ($source)');
    _onAudioEvent?.call(fc, confidence, source);
  }

  void _handleSoundLevel(double level) {
    if (!_isListening) return;

    double normalizedVol = 0.08;
    if (level > 0) {
      normalizedVol = (level / 18.0).clamp(0.08, 1.0);
    } else if (level > -50) {
      normalizedVol = ((level + 50.0) / 50.0).clamp(0.08, 1.0);
    }

    _latestVolume = normalizedVol;
    _latestPitch = (200 + (normalizedVol * 1400).toInt()).clamp(100, 4500);

    final List<double> frame = List<double>.generate(40, (i) {
      final wave = math.sin((i * 0.28) + (DateTime.now().millisecondsSinceEpoch * 0.012)).abs();
      return (normalizedVol * (0.35 + wave * 0.65)).clamp(0.04, 1.0);
    });
    _latestFrame = frame;
    _onAudioFrame?.call(frame, _latestVolume, _latestPitch);
  }

  void _startAmbientWaveTicker() {
    _ambientWaveTimer?.cancel();
    _ambientWaveTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!_isListening) return;
      if (_latestVolume <= 0.10) {
        final vol = 0.05 + (_random.nextDouble() * 0.04);
        final pitch = 180 + _random.nextInt(120);
        final List<double> frame = List<double>.generate(40, (i) {
          final base = (math.sin(timer.tick * 0.2 + i * 0.4).abs() * 0.15);
          return (base + _random.nextDouble() * 0.06).clamp(0.04, 1.0);
        });
        _latestVolume = vol;
        _latestPitch = pitch;
        _latestFrame = frame;
        _onAudioFrame?.call(frame, vol, pitch);
      }
    });
  }

  /// Match Sinhala Unicode Speech, Sinhala Transliterations, and English Emergency Keywords
  void _matchKeywords(String text) {
    final now = DateTime.now();
    if (_alertLatched || now.difference(_lastTriggerTime).inMilliseconds < 1200) return;

    final clean = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0D80-\u0DFF\s]'), ' ');
    final tokens = clean.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    String? matched;

    for (final token in [...tokens, clean]) {
      if (matched != null) break;

      // 1. UDAW ("උදව්", "උදවු", "udaw", "help", "save me")
      if (token.contains('උදව්') ||
          token.contains('උදවු') ||
          token.contains('udaw') ||
          token.contains('udhaw') ||
          token.contains('udhav') ||
          token.contains('udawu') ||
          token.contains('udau') ||
          token.contains('udav') ||
          token.contains('help') ||
          token.contains('save me')) {
        matched = 'udaw';
      }
      // 2. BEERAGANNA ("බේරගන්න", "බේර ගන්න", "beeraganna", "rescue")
      else if (token.contains('බේරගන්න') ||
          token.contains('බේර') ||
          token.contains('බේරගනින්') ||
          token.contains('beeraganna') ||
          token.contains('beraganna') ||
          token.contains('rescue')) {
        matched = 'beeraganna';
      }
      // 3. GINNAK ("ගින්නක්", "ගින්න", "ගින්දර", "ginnak", "fire")
      else if (token.contains('ගින්නක්') ||
          token.contains('ගින්න') ||
          token.contains('ගින්දර') ||
          token.contains('ginnak') ||
          token.contains('ginna') ||
          token.contains('gindara') ||
          token.contains('fire')) {
        matched = 'ginnak';
      }
      // 4. ANATHURAK ("අනතුරක්", "අනතුර", "anathurak", "danger")
      else if (token.contains('අනතුරක්') ||
          token.contains('අනතුර') ||
          token.contains('anathurak') ||
          token.contains('anathura') ||
          token.contains('anadurak') ||
          token.contains('anaturak') ||
          token.contains('danger') ||
          token.contains('hazard')) {
        matched = 'anathurak';
      }
      // 5. KARADARAYAK ("කරදරයක්", "කරදර", "karadarayak", "trouble")
      else if (token.contains('කරදරයක්') ||
          token.contains('කරදර') ||
          token.contains('karadarayak') ||
          token.contains('karadaraya') ||
          token.contains('trouble')) {
        matched = 'karadarayak';
      }
      // 6. BALAGENA ("බලාගෙන", "බලා ගන්න", "balagena", "watch out")
      else if (token.contains('බලාගෙන') ||
          token.contains('බලා') ||
          token.contains('balagena') ||
          token.contains('balagana') ||
          token.contains('watch out') ||
          token.contains('look out')) {
        matched = 'balagena';
      }
      // 7. PARISSAMIN ("පරිස්සමින්", "පරිස්සමෙන්", "parissamin", "careful")
      else if (token.contains('පරිස්සමින්') ||
          token.contains('පරිස්සමෙන්') ||
          token.contains('පරිස්සම්') ||
          token.contains('parissamin') ||
          token.contains('parisamin') ||
          token.contains('careful') ||
          token.contains('caution')) {
        matched = 'parissamin';
      }
      // 8. EHATA WENNA ("එහාට වෙන්න", "එහාට", "ehata")
      else if (token.contains('එහාට') ||
          token.contains('අයින්') ||
          token.contains('ehata') ||
          token.contains('move away')) {
        matched = 'ehata_wenna';
      }
    }

    if (matched != null) {
      _lastTriggerTime = now;
      _alertLatched = true;
      Timer(const Duration(milliseconds: 2200), () {
        _alertLatched = false;
      });
      final displayText = '🗣️ Live Voice: "$text"';
      _latestTranscript = displayText;
      _onSpeechTranscript?.call(displayText);

      _latestAlert = {
        'category': matched,
        'confidence': 0.98,
        'source': 'Voice Speech Recognition: "$text"',
        'timestamp': now.millisecondsSinceEpoch,
      };
      debugPrint('[AudioCaptureNative Keyword Alert]: $matched from "$text"');
      _onAudioEvent?.call(matched, 0.98, 'Voice Speech Recognition: "$text"');
    }
  }

  @override
  void stopCapture() {
    _isListening = false;
    _stopSpeechRecognition();
    _stopAudioStreamer();

    _ambientWaveTimer?.cancel();
    _ambientWaveTimer = null;

    _latestVolume = 0.0;
    _latestPitch = 0;
    _latestFrame = List.generate(40, (i) => 0.02);
    _latestTranscript = "Microphone monitoring paused.";
  }

  @override
  void acknowledgeAlert() {
    _alertLatched = false;
    _latestAlert = null;
    _latestTranscript = "🎤 Listening for Sinhala voice keywords & environmental sounds...";
    _onSpeechTranscript?.call(_latestTranscript);
  }

  @override
  Future<bool> connectBleWatch() async {
    try {
      await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
    } catch (_) {}
    return true;
  }

  @override
  void sendWatchVibration(String priority, {String? title, String? sinhala, String? soundClass}) {}

  @override
  void playSample(String soundName) {
    debugPrint('[AudioCaptureNative] Test sound sample: $soundName');
  }

  @override
  Map<String, dynamic> pollLatestState() {
    return {
      'volume': _latestVolume,
      'pitch': _latestPitch,
      'transcript': _latestTranscript,
      'frame': _latestFrame,
      'alertCategory': _latestAlert?['category'],
      'alertConfidence': _latestAlert?['confidence'] ?? 0.98,
      'alertSource': _latestAlert?['source'],
      'alertTimestamp': _latestAlert?['timestamp'] ?? 0,
    };
  }

  @override
  void setSpeechLanguage(String langCode) {
    _selectedLocaleId = langCode.toLowerCase().startsWith('si') ? _matchedLocaleId : 'en-US';
    _latestTranscript = "🎤 Voice Recognition Language set to: $langCode";
    _onSpeechTranscript?.call(_latestTranscript);
  }

  @override
  void setMonitorMode(String mode) {}

  @override
  void setSensitivity(String level) {}
}
