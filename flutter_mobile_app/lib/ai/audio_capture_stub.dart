import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audio_streamer/audio_streamer.dart';
import 'audio_capture_interface.dart';
import 'native_neural_audio_classifier.dart';

AudioCaptureInterface getAudioCaptureBridge() => AudioCaptureNative();

/// Production-ready Native Android/Mobile Deep Neural Audio & Sinhala Speech Recognition Engine
class AudioCaptureNative implements AudioCaptureInterface {
  final SpeechToText _speechToText = SpeechToText();
  final NativeNeuralAudioClassifier _classifier = NativeNeuralAudioClassifier();
  final math.Random _random = math.Random();
  StreamSubscription<List<double>>? _audioStreamSubscription;

  bool _isListening = false;
  bool _isSpeechInitialized = false;
  String _selectedLocaleId = 'si_LK';
  String _monitorMode = 'dual'; // 'dual', 'voice', 'acoustic'

  DateTime _lastTriggerTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, DateTime> _classCooldown = {};
  int _lastSpeechTriggerMs = 0;
  int _lastMlTime = 0;

  // Exact 1-second circular PCM buffer for Native Neural Network (16,000 Hz)
  static const int _rollingCap = 16000;
  final List<double> _rollingBuf = List<double>.filled(_rollingCap, 0.0);
  int _rollingIdx = 0;
  int _totalPcmReceived = 0;

  double _latestVolume = 0.08;
  int _latestPitch = 220;
  List<double> _latestFrame = List.generate(40, (i) => 0.08);
  String _latestTranscript = "🎤 Native AI Audio & Sinhala Voice Monitor Standby...";
  Map<String, dynamic>? _latestAlert;

  Timer? _restartTimer;
  Timer? _ambientWaveTimer;

  Function(List<double> frame, double volume, int peakFreq)? _onAudioFrame;
  Function(String detectedClass, double confidence, String source)? _onAudioEvent;
  Function(String transcript)? _onSpeechTranscript;

  // Class mapping to match Flutter internal identifiers
  static const Map<String, String?> flutterClassMap = {
    'udaw': 'udaw',
    'beeraganna': 'beeraganna',
    'ginnak': 'ginnak',
    'anathurak': 'anathurak',
    'karadarayak': 'karadarayak',
    'balagena': 'balagena',
    'parissamin': 'parissamin',
    'ehata_wenna': 'ehata_wenna',
    'nawaththanna': 'nawaththanna',
    'screaming': 'screaming',
    'ambulance_siren': 'ambulance',
    'ambulance': 'ambulance',
    'fire_alarm': 'firetruck',
    'firetruck': 'firetruck',
    'vehicle_horn': 'vehicle horns',
    'vehicle horns': 'vehicle horns',
    'baby_crying': 'baby crying',
    'baby crying': 'baby crying',
    'dog_barking': 'dog_bark',
    'dog_bark': 'dog_bark',
    'road': 'road',
    'traffic': 'traffic',
    'background_traffic': null,
  };

  // Tailored confidence thresholds for real-world acoustic capture
  // Non-tonal natural sounds (baby crying, dog bark) have lower continuous power than sirens
  static const Map<String, double> classThresholds = {
    'baby_crying': 0.40,
    'dog_barking': 0.38,
    'vehicle_horn': 0.45,
    'ambulance_siren': 0.58,
    'fire_alarm': 0.58,
    'udaw': 0.42,
    'beeraganna': 0.42,
    'ginnak': 0.42,
    'anathurak': 0.42,
    'karadarayak': 0.42,
    'balagena': 0.42,
    'parissamin': 0.42,
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
    'nawaththanna': 'නවත්තන්න!',
    'screaming': 'කෑගැසීමක්!',
    'ambulance': 'ගිලන් රථ සයිරන්',
    'ambulance_siren': 'ගිලන් රථ සයිරන්',
    'firetruck': 'ගිනි නිවන සංඥාව',
    'fire_alarm': 'ගිනි නිවන සංඥාව',
    'vehicle horns': 'වාහන හෝන්',
    'vehicle_horn': 'වාහන හෝන්',
    'baby crying': 'ළදරු හැඬීම',
    'baby_crying': 'ළදරු හැඬීම',
    'dog_bark': 'බල්ලා බිරීම',
    'dog_barking': 'බල්ලා බිරීම',
    'road': 'මාර්ග ඝෝෂාව',
    'traffic': 'රථවාහන ශබ්දය',
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
    _totalPcmReceived = 0;

    // 1. Request Android Runtime Permissions
    try {
      final mic = await Permission.microphone.request();
      await [
        Permission.notification,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request();
      if (!mic.isGranted) {
        _latestTranscript = "⚠️ Microphone permission required. Please allow microphone in App Settings.";
        onSpeechTranscript(_latestTranscript);
      }
    } catch (e) {
      debugPrint('[AudioCaptureNative] Permission error: $e');
    }

    _latestTranscript = "🎤 Native AI Audio & Sinhala Voice Monitor Active (Say 'උදව්', 'ගින්නක්', 'බේරගන්න')...";
    onSpeechTranscript(_latestTranscript);

    // 2. Load Offline Deep Neural Network Model in Background
    _loadNeuralNetwork();

    // 3. Start continuous ambient visualizer fallback loop
    _startAmbientWaveTicker();

    // 4. Start listening based on active monitor mode
    _applyMonitorMode();
  }

  Future<void> _loadNeuralNetwork() async {
    try {
      final ok = await _classifier.loadModel();
      debugPrint('[AudioCaptureNative] Deep Neural Network loaded: $ok');
    } catch (e) {
      debugPrint('[AudioCaptureNative] Deep Neural Network load error: $e');
    }
  }

  void _applyMonitorMode() {
    if (!_isListening) return;

    if (_monitorMode == 'voice') {
      // Dedicated Voice Recognition Mode: 100% exclusive mic access for SpeechRecognizer
      _stopAudioStreamer();
      _initAndStartSpeechRecognition();
    } else if (_monitorMode == 'acoustic') {
      // Dedicated Environmental Sound AI Mode: 100% exclusive 16kHz access for Deep Neural Net
      _stopSpeechRecognition();
      _startAudioStreamer();
    } else {
      // Dual Auto Mode (Default): Runs 16kHz AudioStreamer for real-time neural sound classification
      // and spoken Sinhala acoustic keyword detection, while maintaining speech fallback
      _startAudioStreamer();
      _initAndStartSpeechRecognition();
    }
  }

  void _startAudioStreamer() {
    try {
      _audioStreamSubscription?.cancel();
      final streamer = AudioStreamer();
      // Record at 16,000 Hz: matches our Deep Neural Network MFCC DSP model 1:1!
      streamer.sampleRate = 16000;
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

  void _stopAudioStreamer() {
    try {
      _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
    } catch (_) {}
  }

  void _processPcmBuffer(List<double> buffer) {
    _totalPcmReceived += buffer.length;

    // 1. Calculate RMS volume, Peak Amplitude, and Zero-Crossing Rate
    double sumSquares = 0.0;
    int zeroCrossings = 0;
    double maxAmp = 0.0;

    for (int i = 0; i < buffer.length; i++) {
      final s = buffer[i];
      final absS = s.abs();
      if (absS > maxAmp) maxAmp = absS;
      sumSquares += s * s;
      if (i > 0 && ((buffer[i - 1] >= 0 && s < 0) || (buffer[i - 1] < 0 && s >= 0))) {
        zeroCrossings++;
      }

      // Store into 1-second rolling circular buffer (16000 samples @ 16kHz)
      _rollingBuf[_rollingIdx] = s;
      _rollingIdx = (_rollingIdx + 1) % _rollingCap;
    }

    final rms = math.sqrt(sumSquares / buffer.length);
    final double normalizedVol = (rms * 8.0).clamp(0.04, 1.0);

    // Dominant frequency estimation
    final double durationSec = buffer.length / 16000.0;
    double estimatedHz = 0.0;
    if (durationSec > 0) {
      estimatedHz = ((zeroCrossings / 2.0) / durationSec).clamp(60.0, 5000.0);
    }

    final int pitchInt = estimatedHz.round();
    _latestVolume = normalizedVol;
    _latestPitch = pitchInt;

    // Build 40-band visualizer frame
    final centerBand = ((estimatedHz / 3500.0) * 40).clamp(2, 38).round();
    final List<double> frame = List<double>.generate(40, (i) {
      final dist = (i - centerBand).abs();
      final spread = math.exp(-dist * 0.18);
      final wave = math.sin((i * 0.3) + (DateTime.now().millisecondsSinceEpoch * 0.015)).abs() * 0.25;
      return (normalizedVol * (spread * 0.75 + wave + 0.1)).clamp(0.04, 1.0);
    });
    _latestFrame = frame;

    _onAudioFrame?.call(frame, _latestVolume, _latestPitch);

    // 2. Real Environmental & Speech Sound Classification via DEEP NEURAL NETWORK
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastMlTime > 250 && _classifier.isLoaded && _totalPcmReceived >= _rollingCap) {
      // Require audible sound to ignore quiet room hum
      if (rms >= 0.008 || maxAmp >= 0.018) {
        _lastMlTime = nowMs;

        // If speech was just recognized, wait 1.2s to prevent voice harmonics from triggering horns
        if (nowMs - _lastSpeechTriggerMs >= 1200) {
          final List<double> window1s = List<double>.filled(_rollingCap, 0.0);
          for (int i = 0; i < _rollingCap; i++) {
            window1s[i] = _rollingBuf[(_rollingIdx + i) % _rollingCap];
          }

          // Exact 16kHz audio: evaluated directly by Deep Neural Network
          final prediction = _classifier.predict(window1s);

          if (prediction != null) {
            // Find the best emergency (non-background) class
            String? bestEmergClass;
            double bestEmergProb = 0.0;
            for (final entry in prediction.allProbabilities.entries) {
              if (entry.key != 'background_traffic' && entry.value > bestEmergProb) {
                bestEmergProb = entry.value;
                bestEmergClass = entry.key;
              }
            }

            if (bestEmergClass != null) {
              final double reqThreshold = classThresholds[bestEmergClass] ?? 0.45;
              if (bestEmergProb >= reqThreshold) {
                _triggerMlAlert(bestEmergClass, bestEmergProb);
              }
            }
          }
        }
      }
    }
  }

  void _triggerMlAlert(String rawCls, double confidence) {
    final now = DateTime.now();
    final fc = flutterClassMap[rawCls];
    if (fc == null) return; // Skip background traffic

    // Global cooldown: 1.8s between any detection
    if (now.difference(_lastTriggerTime).inMilliseconds < 1800) return;

    // Per-class cooldown: 5.0s between detections of the same class
    final lastClassTime = _classCooldown[fc];
    if (lastClassTime != null && now.difference(lastClassTime).inMilliseconds < 5000) {
      return;
    }

    _lastTriggerTime = now;
    _classCooldown[fc] = now;

    final sinhala = sinhalaTitles[fc] ?? fc;
    final source = "Deep Neural Model: $rawCls (${(confidence * 100).toStringAsFixed(0)}%)";

    // Distinguish between spoken Sinhala voice keywords and environmental sounds in transcript
    final isVoiceKeyword = ['udaw', 'beeraganna', 'ginnak', 'anathurak', 'karadarayak', 'balagena', 'parissamin', 'ehata_wenna', 'nawaththanna', 'screaming'].contains(fc);
    if (isVoiceKeyword) {
      _latestTranscript = "🚨 Voice Detected: $sinhala ($fc)";
    } else {
      _latestTranscript = "🚨 Sound Detected: $sinhala ($fc)";
    }
    _onSpeechTranscript?.call(_latestTranscript);

    _latestAlert = {
      'category': fc,
      'confidence': confidence,
      'source': source,
      'timestamp': now.millisecondsSinceEpoch,
    };

    debugPrint('[AudioCaptureNative Neural Net Triggered]: $fc ($source)');
    _onAudioEvent?.call(fc, confidence, source);
  }

  Future<void> _initAndStartSpeechRecognition() async {
    if (!_isListening) return;

    try {
      if (!_isSpeechInitialized) {
        _isSpeechInitialized = await _speechToText.initialize(
          onStatus: (status) {
            debugPrint('[AudioCaptureNative STT Status]: $status');
            if (!_isListening) return;
            if (status == 'listening') {
              if (!_latestTranscript.startsWith('🗣️') && !_latestTranscript.startsWith('🚨')) {
                _latestTranscript = "🎤 Listening for Sinhala: 'උදව්', 'ගින්නක්', 'බේරගන්න'...";
                _onSpeechTranscript?.call(_latestTranscript);
              }
            } else if (status == 'notListening' || status == 'done') {
              _scheduleSpeechRestart();
            }
          },
          onError: (errorNotification) {
            debugPrint('[AudioCaptureNative STT Error]: ${errorNotification.errorMsg}');
            if (!_isListening) return;
            // Fall back to system locale if si_LK is missing offline on the device
            if (_selectedLocaleId != 'system') {
              _selectedLocaleId = 'system';
            }
            _scheduleSpeechRestart(delayMs: 1200);
          },
        );

        if (_isSpeechInitialized) {
          try {
            final locales = await _speechToText.locales();
            bool foundSinhala = false;
            for (final loc in locales) {
              final id = loc.localeId.toLowerCase();
              if (id.startsWith('si') || id.contains('lk')) {
                _selectedLocaleId = loc.localeId;
                foundSinhala = true;
                debugPrint('[AudioCaptureNative] Found Sinhala Locale: $_selectedLocaleId');
                break;
              }
            }
            if (!foundSinhala && _selectedLocaleId == 'si_LK') {
              _selectedLocaleId = 'system';
            }
          } catch (e) {
            debugPrint('[AudioCaptureNative] Locales lookup error: $e');
          }
        }
      }

      if (_isSpeechInitialized && _isListening) {
        _startListeningSession();
      } else {
        _restartTimer?.cancel();
        _restartTimer = Timer(const Duration(milliseconds: 1500), () {
          if (_isListening && !_isSpeechInitialized) {
            _initAndStartSpeechRecognition();
          }
        });
      }
    } catch (e) {
      debugPrint('[AudioCaptureNative] STT Init exception: $e');
      _scheduleSpeechRestart(delayMs: 1500);
    }
  }

  void _stopSpeechRecognition() {
    _restartTimer?.cancel();
    _restartTimer = null;
    try {
      _speechToText.stop();
    } catch (_) {}
  }

  void _startListeningSession() async {
    if (!_isListening || _speechToText.isListening) return;

    try {
      final options = SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        autoPunctuation: true,
        enableHapticFeedback: false,
      );

      final targetLocale = (_selectedLocaleId == 'system' || _selectedLocaleId.isEmpty) ? null : _selectedLocaleId;

      await _speechToText.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            final displayText = '🗣️ Heard Voice: "$words"';
            _latestTranscript = displayText;
            _onSpeechTranscript?.call(displayText);
            _matchKeywords(words);
          }
        },
        listenOptions: options,
        localeId: targetLocale,
        onSoundLevelChange: (level) {
          _handleSoundLevel(level);
        },
      );
    } catch (e) {
      debugPrint('[AudioCaptureNative] STT listen error: $e');
      _scheduleSpeechRestart(delayMs: 1000);
    }
  }

  void _scheduleSpeechRestart({int delayMs = 350}) {
    if (!_isListening) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_isListening && !_speechToText.isListening) {
        _startListeningSession();
      }
    });
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
    if (now.difference(_lastTriggerTime).inMilliseconds < 1000) return;

    final clean = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0D80-\u0DFF\s]'), ' ');

    String? matched;

    // 1. HELP / UDAW ("උදව්", "උදවු", "උදව්වක්", "උදව් කරන්න", "udaw", "help", "save")
    if (clean.contains('උදව්') ||
        clean.contains('උදවු') ||
        clean.contains('උදව') ||
        clean.contains('udaw') ||
        clean.contains('udau') ||
        clean.contains('udav') ||
        clean.contains('udaau') ||
        clean.contains('help') ||
        clean.contains('save me') ||
        clean.contains('save') ||
        clean.contains('you dow') ||
        clean.contains('wood how') ||
        clean.contains('who dow') ||
        clean.contains('u dow')) {
      matched = 'udaw';
    }
    // 2. RESCUE / BEERAGANNA ("බේරගන්න", "බේර ගන්න", "බේරගනින්", "බේරන්න", "beeraganna", "rescue")
    else if (clean.contains('බේරගන්න') ||
        clean.contains('බේර ගන්න') ||
        clean.contains('බේරගනින්') ||
        clean.contains('බේරන්න') ||
        clean.contains('බේරපන්') ||
        clean.contains('beeraganna') ||
        clean.contains('beraganna') ||
        clean.contains('beeranna') ||
        clean.contains('beranna') ||
        clean.contains('rescue') ||
        clean.contains('beer gonna') ||
        clean.contains('better gonna') ||
        clean.contains('bear gonna')) {
      matched = 'beeraganna';
    }
    // 3. FIRE / GINNAK ("ගින්නක්", "ගින්න", "ගින්දර", "ginnak")
    else if (clean.contains('ගින්නක්') ||
        clean.contains('ගින්න') ||
        clean.contains('ගින්දර') ||
        clean.contains('ගිනි') ||
        clean.contains('ginnak') ||
        clean.contains('ginna') ||
        clean.contains('gindara') ||
        clean.contains('fire') ||
        clean.contains('burning') ||
        clean.contains('gin knock') ||
        clean.contains('gin duck') ||
        clean.contains('green lock')) {
      matched = 'ginnak';
    }
    // 4. DANGER / ANATHURAK ("අනතුරක්", "අනතුර", "අනතුරු", "anathurak", "danger")
    else if (clean.contains('අනතුරක්') ||
        clean.contains('අනතුර') ||
        clean.contains('අනතුරු') ||
        clean.contains('anathurak') ||
        clean.contains('anaturak') ||
        clean.contains('anature') ||
        clean.contains('danger') ||
        clean.contains('hazard') ||
        clean.contains('accident') ||
        clean.contains('another rug') ||
        clean.contains('on a truck')) {
      matched = 'anathurak';
    }
    // 5. TROUBLE / KARADARAYAK ("කරදරයක්", "කරදර", "කරදරේ", "karadarayak")
    else if (clean.contains('කරදරයක්') ||
        clean.contains('කරදර') ||
        clean.contains('කරදරේ') ||
        clean.contains('karadarayak') ||
        clean.contains('karadare') ||
        clean.contains('trouble')) {
      matched = 'karadarayak';
    }
    // 6. WATCH OUT / BALAGENA ("බලාගෙන", "බලා ගෙන", "balagena", "watch out")
    else if (clean.contains('බලාගෙන') ||
        clean.contains('බලා ගෙන') ||
        clean.contains('බලාපන්') ||
        clean.contains('balagena') ||
        clean.contains('balaagena') ||
        clean.contains('watch out') ||
        clean.contains('look out')) {
      matched = 'balagena';
    }
    // 7. BE CAREFUL / PARISSAMIN ("පරිස්සමින්", "පරිස්සමෙන්", "පරිස්සම්", "parissamin", "careful")
    else if (clean.contains('පරිස්සමින්') ||
        clean.contains('පරිස්සමෙන්') ||
        clean.contains('පරිස්සම්') ||
        clean.contains('parissamin') ||
        clean.contains('parissamen') ||
        clean.contains('careful') ||
        clean.contains('caution')) {
      matched = 'parissamin';
    }
    // 8. MOVE AWAY / EHATA WENNA ("එහාට වෙන්න", "එහාට", "අයින් වෙන්න", "ehata")
    else if (clean.contains('එහාට වෙන්න') ||
        clean.contains('එහාට') ||
        clean.contains('අයින් වෙන්න') ||
        clean.contains('ehata') ||
        clean.contains('move away')) {
      matched = 'ehata_wenna';
    }
    // 9. STOP / NAWATHTHANNA ("නවත්තන්න", "නවත්වන්න", "නවත්තපන්", "නවතින්න", "nawaththanna", "stop")
    else if (clean.contains('නවත්තන්න') ||
        clean.contains('නවත්වන්න') ||
        clean.contains('නවත්තපන්') ||
        clean.contains('නවතින්න') ||
        clean.contains('nawaththanna') ||
        clean.contains('nawathwanna') ||
        clean.contains('stop')) {
      matched = 'nawaththanna';
    }
    // 10. SCREAMING ("කෑගැසීමක්", "කෑ ගහනවා", "scream", "screaming")
    else if (clean.contains('කෑගැසීම') ||
        clean.contains('කෑ ගහනවා') ||
        clean.contains('කෑගහනවා') ||
        clean.contains('scream') ||
        clean.contains('screaming')) {
      matched = 'screaming';
    }

    if (matched != null) {
      _lastSpeechTriggerMs = now.millisecondsSinceEpoch;
      _lastTriggerTime = now;
      final sinhala = sinhalaTitles[matched] ?? matched;
      final displayText = '🗣️ Heard: "$text" ➔ 🚨 $sinhala';
      _latestTranscript = displayText;
      _onSpeechTranscript?.call(displayText);

      _latestAlert = {
        'category': matched,
        'confidence': 0.98,
        'source': 'Voice Speech Recognition: "$text"',
        'timestamp': now.millisecondsSinceEpoch,
      };
      debugPrint('[AudioCaptureNative Emergency Keyword Triggered]: $matched from "$text"');
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
    debugPrint('[AudioCaptureNative] Test sound sample triggered: $soundName');
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
    debugPrint('[AudioCaptureNative] Language switch requested: $langCode');
    if (langCode.toLowerCase().startsWith('si')) {
      _selectedLocaleId = 'si_LK';
    } else {
      _selectedLocaleId = 'en_US';
    }

    _latestTranscript = "🎤 Voice Recognition Language set to: $langCode";
    _onSpeechTranscript?.call(_latestTranscript);

    if (_isListening) {
      _speechToText.stop().then((_) {
        _startListeningSession();
      }).catchError((_) {
        _startListeningSession();
      });
    }
  }

  @override
  void setMonitorMode(String mode) {
    debugPrint('[AudioCaptureNative] Monitor Mode updated to: $mode');
    _monitorMode = mode;
    if (_isListening) {
      _applyMonitorMode();
    }
  }

  @override
  void setSensitivity(String level) {
    debugPrint('[AudioCaptureNative] Sensitivity updated to: $level');
  }
}
