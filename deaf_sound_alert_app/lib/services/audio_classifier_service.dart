import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audio_streamer/audio_streamer.dart';
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
  AudioStreamer? _audioStreamer;
  AudioRecorder? _pcmRecorder;
  StreamSubscription? _pcmStreamSubscription;

  Timer? _sttWatchdogTimer;
  bool _speechAvailable = false;
  String? _selectedLocaleId;
  bool _isListening = false;
  bool _isOfflineMode = false;
  bool _isAnimatingTranscript = false;
  Timer? _offlineNetCheckTimer;
  String? _pendingSinhalaClass;
  int _pendingSinhalaHits = 0;
  int _pendingSinhalaMs = 0;
  String? _pendingEnvClass;
  int _pendingEnvHits = 0;
  int _pendingEnvMs = 0;

  static const List<String> _sinhalaClasses = [
    'udaw',
    'beeraganna',
    'beraganna',
    'ginnak',
    'anathurak',
    'karadarayak',
    'balagena',
    'parissamin',
    'ehata_wenna',
  ];

  final Map<String, List<String>> _progressiveSteps = {
    'sinhala_udaw_': ['උ...', 'උද...', 'උදව්', 'උදව් (Udaw - Help)'],
    'sinhala_beraganna_': ['බේ...', 'බේරා...', 'බේරාගන්න', 'බේරාගන්න (Beraganna - Save Me)'],
    'sinhala_ginnak_': ['ගි...', 'ගින්...', 'ගින්නක්', 'ගින්නක් (Ginnak - Fire)'],
    'sinhala_anathurak_': ['අන...', 'අනතු...', 'අනතුරක්', 'අනතුරක් (Anathurak - Danger)'],
    'sinhala_karadarayak_': ['කර...', 'කරදර...', 'කරදරයක්', 'කරදරයක් (Karadarayak - Trouble)'],
    'sinhala_balagena_': ['බලා...', 'බලාගෙන', 'බලාගෙන (Balaagena - Watch Out)'],
    'sinhala_ehata_wenna_': ['එහා...', 'එහාට වෙන්න', 'එහාට වෙන්න (Ehata Wenna - Move Aside)'],
    'sinhala_parissamin_': ['පරි...', 'පරිස්...', 'පරිස්සමින්', 'පරිස්සමින් (Parissamin - Be Careful)'],
  };

  double _latestSoundVolume = 0.02;
  final List<double> _visualizerBars = List<double>.filled(40, 0.15);

  // 16,000 Hz circular rolling audio buffer (1 second)
  final List<double> _rollingBuf16k = List<double>.filled(16000, 0.0);
  int _rollingIdx = 0;
  int _total16kPushed = 0;
  int _hardwareSampleRate = 16000;
  int _lastPcmTimeMs = 0;
  int _lastMlTimeMs = 0;
  int _lastSpeechTimeMs = 0;
  DateTime? _lastGlobalAlertTime;

  final Map<String, DateTime> _lastKeywordTriggerTimes = {};

  final _controller = StreamController<DetectedSound>.broadcast();
  final _waveformController = StreamController<List<double>>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();
  final _diagController = StreamController<String>.broadcast();

  bool get isListening => _isListening;
  Stream<DetectedSound> get onSoundDetected => _controller.stream;
  Stream<List<double>> get onWaveformUpdated => _waveformController.stream;
  Stream<String> get onTranscriptUpdated => _transcriptController.stream;
  Stream<String> get onDiagnosticsUpdated => _diagController.stream;

  final Map<String, String> _labelToSoundKey = {
    'ambulance_siren': 'ambulance',
    'ambulance': 'ambulance',
    'firetruck': 'firetruck',
    'fire_truck': 'firetruck',
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
    'sinhala_udaw_': 'උදව් (Udaw - Help)',
    'sinhala_anathurak_': 'අනතුරක් (Anathurak - Danger)',
    'sinhala_beraganna_': 'බේරාගන්න (Beraganna - Save Me)',
    'sinhala_ginnak_': 'ගින්නක් (Ginnak - Fire)',
    'sinhala_karadarayak_': 'කරදරයක් (Karadarayak - Trouble)',
    'sinhala_balagena_': 'බලාගෙන (Balaagena - Watch Out)',
    'sinhala_ehata_wenna_': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
    'sinhala_parissamin_': 'පරිස්සමින් (Parissamin - Be Careful)',
    'ambulance': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
    'firetruck': 'ගිනි නිවන රථ ශබ්දය (Fire Truck Siren)',
    'fire_truck': 'ගිනි නිවන රථ ශබ්දය (Fire Truck Siren)',
    'baby crying': 'ළදරු හැඬීම (Baby Crying)',
    'vehicle horns': 'වාහන හොන් (Vehicle Horns)',
    'dog_bark_dataset': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
    'traffic': 'වාහන තදබදය (Traffic Noise)',
    'road': 'පාරේ ශබ්දය (Road Sounds)',
  };

  Future<void> init() async {
    final modelLoaded = await _neuralClassifier.loadModel();
    if (!modelLoaded) {
      print('Offline audio model could not be loaded');
    }

    try {
      _speechAvailable = await _speech.initialize(
        onError: (val) {
          _onSpeechError(val.errorMsg);
        },
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
            final id = loc.localeId.toLowerCase();
            if (id.startsWith('si') || id.contains('sinhala')) {
              _selectedLocaleId = loc.localeId;
              break;
            }
          }
        } catch (_) {}
        _selectedLocaleId ??= 'si_LK';
      }
    } catch (_) {
      _speechAvailable = false;
    }
  }

  bool _isRestartingStt = false;
  Timer? _visualizerTicker;

  void _updateWaveformVolume(double newVol) {
    final double targetVol = newVol.clamp(0.18, 1.0);
    if (targetVol > _latestSoundVolume) {
      _latestSoundVolume = targetVol;
    } else {
      _latestSoundVolume = (_latestSoundVolume * 0.65 + targetVol * 0.35).clamp(0.18, 1.0);
    }
  }

  void _startVisualizerTicker() {
    _visualizerTicker?.cancel();
    _visualizerTicker = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!_isListening) {
        timer.cancel();
        return;
      }

      final double nowSec = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final List<double> newFrame = List<double>.generate(40, (band) {
        final double centerDist = ((band - 20) / 20.0).abs();
        final double centerEnvelope = math.exp(-centerDist * centerDist * 1.2);

        final double ripple1 = math.sin(band * 0.40 + nowSec * 6.0).abs() * 0.10;
        final double ripple2 = math.cos(band * 0.70 - nowSec * 7.5).abs() * 0.08;

        double targetHeight;
        if (_latestSoundVolume < 0.06) {
          targetHeight = (0.15 + centerEnvelope * 0.12 + ripple1 + ripple2).clamp(0.12, 0.35);
        } else {
          targetHeight = (_latestSoundVolume * (centerEnvelope * 0.70 + ripple1 * 0.6 + 0.35)).clamp(0.18, 1.0);
        }
        return targetHeight;
      });

      for (int i = 0; i < 40; i++) {
        _visualizerBars[i] = _visualizerBars[i] * 0.55 + newFrame[i] * 0.45;
      }

      _waveformController.add(List<double>.from(_visualizerBars));

      // Smooth decay back to baseline volume
      _latestSoundVolume = (_latestSoundVolume * 0.88).clamp(0.04, 1.0);
    });
  }

  void _safeListenSpeech() async {
    if (!_isListening || _isRestartingStt) return;
    if (_speech.isListening) return; // Keep active speech recognition session running uninterrupted!

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
    } catch (_) {}

    try {
      final String? targetLocale = (_selectedLocaleId != null && _selectedLocaleId!.isNotEmpty) ? _selectedLocaleId : null;

      await _speech.listen(
        onResult: (result) {
          if (!_isListening || _isAnimatingTranscript) return;
          final String rawWords = result.recognizedWords.trim();
          if (rawWords.isNotEmpty) {
            _lastSpeechTimeMs = DateTime.now().millisecondsSinceEpoch;
            final String formattedDisplay = _formatTranscriptWithSinhala(rawWords);
            _transcriptController.add(formattedDisplay);
            _processSpeechText(rawWords.toLowerCase());
          }
        },
        onSoundLevelChange: (level) {
          if (!_isListening) return;
          double soundVol = (0.25 + (level.clamp(-2.0, 10.0) / 10.0)).clamp(0.18, 1.0);
          _updateWaveformVolume(soundVol);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.deviceDefault,
          partialResults: true,
          cancelOnError: false,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(hours: 1),
        ),
        localeId: targetLocale,
      );
    } catch (e) {
      _onSpeechError(e.toString());
    } finally {
      _isRestartingStt = false;
    }
  }



  void _onSpeechDone() {
    if (!_isListening) return;
    Timer(const Duration(milliseconds: 300), () {
      if (_isListening && !_speech.isListening && !_isRestartingStt) {
        _safeListenSpeech();
      }
    });
  }

  void _onSpeechError(String errorMsg) {
    if (!_isListening) return;
    final String err = errorMsg.toLowerCase();
    if (err.contains('network') || err.contains('error_network') || err.contains('unavailable')) {
      _isOfflineMode = true;
      try {
        _speech.stop();
      } catch (_) {}
      _startAudioStreamer();
      return;
    }
    if (err.contains('language') || err.contains('locale') || err.contains('not_supported')) {
      _selectedLocaleId = "";
    }
    Timer(const Duration(milliseconds: 500), () {
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
        Permission.camera,
      ].request();
    } catch (_) {}

    _isListening = true;
    _isRestartingStt = false;
    _isAnimatingTranscript = false;
    _rollingIdx = 0;
    _total16kPushed = 0;
    _latestSoundVolume = 0.25;

    // Start 50 FPS smooth visualizer animation ticker
    _startVisualizerTicker();

    // 1. Ensure on-device neural classifier model is loaded
    if (!_neuralClassifier.isLoaded) {
      await _neuralClassifier.loadModel();
    }

    _pendingSinhalaClass = null;
    _pendingSinhalaHits = 0;
    _pendingSinhalaMs = 0;
    _pendingEnvClass = null;
    _pendingEnvHits = 0;
    _pendingEnvMs = 0;

    // 2. Start continuous Google STT engine for live online speech
    _safeListenSpeech();

    // 3. Start audio stream for visualizer & offline neural classification
    final streamerStarted = await _startAudioStreamer();
    if (!streamerStarted) {
      final fallbackStarted = await _startRecordPcmFallback();
      if (!fallbackStarted && !_speechAvailable) {
        _isListening = false;
        _visualizerTicker?.cancel();
        print('Offline mode unavailable: microphone stream could not start');
        return false;
      }
    }

    return true;
  }

  Future<bool> _startAudioStreamer() async {
    try {
      _pcmStreamSubscription?.cancel();
      _pcmStreamSubscription = null;
      _audioStreamer = AudioStreamer();
      // The classifier expects 16 kHz PCM. Set this before accessing audioStream.
      _audioStreamer!.sampleRate = 16000;

      _pcmStreamSubscription = _audioStreamer!.audioStream.listen(
        (buffer) {
          if (!_isListening || buffer.isEmpty) return;
          _processPcmBuffer(buffer);
        },
        onError: (error) {
          print('AudioStreamer error: $error');
        },
        cancelOnError: false,
      );
      if (_pcmStreamSubscription == null) return false;

      try {
        final rate = await _audioStreamer!.actualSampleRate;
        if (rate > 0) _hardwareSampleRate = rate;
      } catch (_) {
        _hardwareSampleRate = 44100;
      }
      if (_hardwareSampleRate <= 0) _hardwareSampleRate = 44100;
    } catch (e) {
      print('AudioStreamer init error: $e');
      _pcmStreamSubscription?.cancel();
      _pcmStreamSubscription = null;
      _audioStreamer = null;
      return false;
    }
    return true;
  }

  Future<bool> _startRecordPcmFallback() async {
    try {
      await _pcmRecorder?.stop();
    } catch (_) {}
    _pcmRecorder = AudioRecorder();
    try {
      if (!await _pcmRecorder!.hasPermission()) return false;
      _hardwareSampleRate = 16000;
      final stream = await _pcmRecorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: 16000,
        ),
      );
      _pcmStreamSubscription?.cancel();
      _pcmStreamSubscription = stream.listen(
        (bytes) {
          if (!_isListening || bytes.isEmpty) return;
          final samples = List<double>.generate(bytes.length ~/ 2, (i) {
            int byte0 = bytes[i * 2];
            int byte1 = bytes[i * 2 + 1];
            int val = (byte1 << 8) | byte0;
            if (val >= 32768) val -= 65536;
            return val / 32768.0;
          });
          _processPcmBuffer(samples);
        },
        onError: (error) {
          print('PCM recorder error: $error');
        },
        cancelOnError: false,
      );
      return true;
    } catch (e) {
      print('PCM recorder fallback error: $e');
      try {
        await _pcmRecorder?.stop();
      } catch (_) {}
      _pcmRecorder = null;
      return false;
    }
  }

  void _processPcmBuffer(List<double> rawBuffer) {
    if (rawBuffer.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    double maxRaw = 0.0;
    for (int i = 0; i < rawBuffer.length; i++) {
      final a = rawBuffer[i].abs();
      if (a > maxRaw) maxRaw = a;
    }

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

    final double normScale = maxRaw > 2.0 ? (1.0 / 32768.0) : 1.0;
    const double gainBoost = 1.0;

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
    
    // Pass real mic volume & 40-band pitch spectrum directly to wave visualizer continuously
    final double soundVol = (maxAmp * 4.0 + rms * 12.0).clamp(0.0, 1.0);
    final double nowSec = nowMs / 1000.0;
    
    final List<double> newFrame = List<double>.generate(40, (band) {
      final int startSample = (band * (packet16k.length / 40.0)).floor();
      final int endSample = math.min(packet16k.length, ((band + 1) * (packet16k.length / 40.0)).floor());
      
      double bandAmp = 0.0;
      for (int k = startSample; k < endSample; k++) {
        final a = packet16k[k].abs();
        if (a > bandAmp) bandAmp = a;
      }
      
      final double centerDist = ((band - 20) / 20.0).abs();
      final double centerEnvelope = math.exp(-centerDist * centerDist * 1.2);

      // Organic dynamic micro-waves so visualizer baseline is alive and NEVER freezes into a static shape!
      final double ripple1 = math.sin(band * 0.40 + nowSec * 4.0).abs() * 0.08;
      final double ripple2 = math.cos(band * 0.70 - nowSec * 5.5).abs() * 0.06;

      double targetHeight;
      if (soundVol < 0.008) {
        // Resting baseline: lively micro-bouncing waveform (0.12 - 0.32)
        targetHeight = (0.14 + centerEnvelope * 0.10 + ripple1 + ripple2).clamp(0.12, 0.32);
      } else {
        // Sound / Speech active: energetic response to mic volume and pitch
        final double scaledBand = (bandAmp * 5.0 + soundVol * 0.8).clamp(0.20, 1.0);
        targetHeight = (scaledBand * (centerEnvelope * 0.65 + ripple1 * 0.5 + 0.30)).clamp(0.18, 1.0);
      }
      return targetHeight;
    });

    // Apply smooth exponential moving average across frames for fluid bouncing motion (0 Lag)
    for (int i = 0; i < 40; i++) {
      _visualizerBars[i] = _visualizerBars[i] * 0.50 + newFrame[i] * 0.50;
    }

    _waveformController.add(List<double>.from(_visualizerBars));

    // OFFLINE LIVE SPEECH & SOUND DETECTION ENGINE:
    // Identical functionality to online mode:
    // 1. Spoken words transcribe live to the speech box and trigger emergency alert cards
    // 2. Direct word match on the 8 Sinhala emergency keywords (near or far from mic)
    // 3. Environmental sounds ONLY trigger when no speech is occurring (prevents wrong sounds!)
    if (!_isAnimatingTranscript && _total16kPushed >= 14000) {
      if (nowMs - _lastMlTimeMs >= 100 && (rms >= 0.006 || maxAmp >= 0.025)) {
        _lastMlTimeMs = nowMs;

        final List<double> window1s = List<double>.filled(16000, 0.0);
        double peakAmp = 0.0;
        double sumSq1s = 0.0;
        for (int i = 0; i < 16000; i++) {
          final double val = _rollingBuf16k[(_rollingIdx - 16000 + i + 16000) % 16000];
          window1s[i] = val;
          final a = val.abs();
          if (a > peakAmp) peakAmp = a;
          sumSq1s += val * val;
        }

        final double rms1s = math.sqrt(sumSq1s / 16000);

        // Only evaluate when genuine sound or speech energy is present (ignores quiet ambient hiss)
        if (peakAmp >= 0.035 && rms1s >= 0.008) {
          // Standardize acoustic power for speech distance invariance (near or far from mic)
          final sBoosted = List<double>.generate(
            16000,
            (i) => (window1s[i] * (0.28 / peakAmp).clamp(1.0, 6.0)).clamp(-1.0, 1.0),
          );

          final pred = _neuralClassifier.predict(sBoosted);

          if (pred != null) {
            final now = DateTime.now();
            final bool canAlert = (_lastGlobalAlertTime == null ||
                now.difference(_lastGlobalAlertTime!).inMilliseconds > 4000);
            final allProbs = pred.allProbabilities;

            // Track speech presence
            double totalSpeechProb = 0.0;
            for (var sc in _sinhalaClasses) {
              totalSpeechProb += (allProbs[sc] ?? 0.0);
            }
            if (totalSpeechProb >= 0.15 || pred.label == 'other_speech') {
              _lastSpeechTimeMs = nowMs;
            }

            final sinhalaHit = canAlert ? _matchSinhalaKeyword(allProbs, pred.label) : null;

            if (sinhalaHit != null) {
              // Reset any pending environmental sound tracking
              _pendingEnvClass = null;
              _pendingEnvHits = 0;
              _lastSpeechTimeMs = nowMs;

              if (_pendingSinhalaClass == sinhalaHit.className && nowMs - _pendingSinhalaMs < 500) {
                _pendingSinhalaHits++;
              } else {
                _pendingSinhalaClass = sinhalaHit.className;
                _pendingSinhalaHits = 1;
              }
              _pendingSinhalaMs = nowMs;

              if (_pendingSinhalaHits >= 2) {
                _pendingSinhalaClass = null;
                _pendingSinhalaHits = 0;

                final mappedKey = _labelToSoundKey[sinhalaHit.className] ?? sinhalaHit.className;
                final lastHitTime = _lastKeywordTriggerTimes[mappedKey];
                final bool classCooldownOk = (lastHitTime == null || now.difference(lastHitTime).inMilliseconds > 5500);

                if (canAlert && classCooldownOk) {
                  _lastGlobalAlertTime = now;
                  _lastKeywordTriggerTimes[mappedKey] = now;
                  _lastSpeechTimeMs = nowMs + 4500;
                  _rollingBuf16k.fillRange(0, 16000, 0.0);
                  _total16kPushed = 0;
                  _pendingSinhalaClass = null;
                  _pendingSinhalaHits = 0;
                  _pendingEnvClass = null;
                  _pendingEnvHits = 0;

                  // Stop STT listening if active so it doesn't collide with offline recognition
                  try {
                    if (_speech.isListening) {
                      _speech.stop();
                    }
                  } catch (_) {}

                  _animateOfflineTranscriptAndAlert(mappedKey);
                  return;
                }
              }
            } else {
              if (nowMs - _pendingSinhalaMs > 250) {
                _pendingSinhalaClass = null;
                _pendingSinhalaHits = 0;
              }

              // ENVIRONMENTAL SOUNDS (vehicle horns, ambulance, fire truck, dog barking, baby crying, traffic noise):
              // Responsive and reliable detection:
              // 1. Must NOT have active speech (idle >= 1200ms and totalSpeechProb < 0.15)
              // 2. Sound volume active (peakAmp >= 0.035, rms >= 0.008)
              // 3. Top class is environmental emergency/alert class (confidence >= 0.70, margin >= 0.35)
              // 4. Confirmed across 2 frames within 700ms for swift 0-delay response!
              if (canAlert && (nowMs - _lastSpeechTimeMs >= 1200) && totalSpeechProb < 0.15 && peakAmp >= 0.035) {
                final String top = pred.label;
                final double topP = pred.probability;

                const envClasses = {
                  'vehicle_horn': 'vehicle horns',
                  'ambulance_siren': 'ambulance',
                  'firetruck': 'firetruck',
                  'fire_truck': 'firetruck',
                  'dog_barking': 'dog_bark_dataset',
                  'baby_crying': 'baby crying',
                  'background_traffic': 'traffic',
                };

                if (envClasses.containsKey(top)) {
                  double runnerUp = 0.0;
                  allProbs.forEach((k, v) {
                    if (k != top && v > runnerUp) runnerUp = v;
                  });

                  final double margin = topP - runnerUp;
                  if (topP >= 0.70 && margin >= 0.35) {
                    if (_pendingEnvClass == top && (nowMs - _pendingEnvMs < 700)) {
                      _pendingEnvHits++;
                    } else {
                      _pendingEnvClass = top;
                      _pendingEnvHits = 1;
                    }
                    _pendingEnvMs = nowMs;

                    if (_pendingEnvHits >= 2) {
                      _pendingEnvClass = null;
                      _pendingEnvHits = 0;
                      final soundKey = envClasses[top]!;
                      final lastHitTime = _lastKeywordTriggerTimes[soundKey];
                      final bool classCooldownOk = (lastHitTime == null || now.difference(lastHitTime).inMilliseconds > 3500);

                      if (classCooldownOk) {
                        _lastGlobalAlertTime = now;
                        _lastKeywordTriggerTimes[soundKey] = now;
                        _rollingBuf16k.fillRange(0, 16000, 0.0);
                        _total16kPushed = 0;
                        simulateSoundDetection(soundKey, confidence: topP, overrideCooldown: true);
                      }
                    }
                  } else {
                    _pendingEnvClass = null;
                    _pendingEnvHits = 0;
                  }
                } else {
                  _pendingEnvClass = null;
                  _pendingEnvHits = 0;
                }
              }
            }
          }
        }
      }
    }
  }

  _SinhalaHit? _matchSinhalaKeyword(Map<String, double> allProbs, String topLabel) {
    if (!_sinhalaClasses.contains(topLabel)) return null;

    final double topP = allProbs[topLabel] ?? 0.0;
    if (topP < 0.75) return null;

    double runnerUp = 0.0;
    allProbs.forEach((name, p) {
      if (name != topLabel && p > runnerUp) {
        runnerUp = p;
      }
    });

    final double margin = topP - runnerUp;
    if (margin >= 0.40) {
      return _SinhalaHit(topLabel, topP);
    }
    return null;
  }

  void _animateOfflineTranscriptAndAlert(String key) async {
    if (_isAnimatingTranscript) return;
    _isAnimatingTranscript = true;

    try {
      final steps = _progressiveSteps[key] ?? [_displayNames[key] ?? key];

      // Display letter by letter / word by word in the live speech box (SAME as online speech typing!)
      for (int i = 0; i < steps.length; i++) {
        _transcriptController.add(steps[i]);
        await Future.delayed(const Duration(milliseconds: 120));
      }

      // Allow user to clearly see the full recognized Sinhala word in the Live Speech box before alert card pops up
      await Future.delayed(const Duration(milliseconds: 350));

      await simulateSoundDetection(key, confidence: 0.99, overrideCooldown: true);

      // CRITICAL: Immediately clear rolling buffer and reset pending state so trailing utterance decay NEVER triggers wrong cards!
      final completedNow = DateTime.now();
      _lastGlobalAlertTime = completedNow;
      _lastKeywordTriggerTimes[key] = completedNow;
      _lastSpeechTimeMs = completedNow.millisecondsSinceEpoch;
      _rollingBuf16k.fillRange(0, 16000, 0.0);
      _total16kPushed = 0;
      _pendingSinhalaClass = null;
      _pendingSinhalaHits = 0;
      _pendingEnvClass = null;
      _pendingEnvHits = 0;
    } catch (_) {
    } finally {
      _isAnimatingTranscript = false;
    }
  }

  String _formatTranscriptWithSinhala(String rawWords) {
    final String lower = rawWords.toLowerCase();

    final Map<String, String> wordToSinhala = {
      'udaw': 'උදව් (Udaw - Help)',
      'udau': 'උදව් (Udaw - Help)',
      'udaww': 'උදව් (Udaw - Help)',
      'help': 'උදව් (Udaw - Help)',
      'sos': 'උදව් (Udaw - Help)',
      'emergency': 'උදව් (Udaw - Help)',
      'උදව්': 'උදව් (Udaw - Help)',
      'උදවු': 'උදව් (Udaw - Help)',
      'anathurak': 'අනතුරක් (Anathurak - Danger)',
      'anatura': 'අනතුරක් (Anathurak - Danger)',
      'danger': 'අනතුරක් (Anathurak - Danger)',
      'accident': 'අනතුරක් (Anathurak - Danger)',
      'warning': 'අනතුරක් (Anathurak - Danger)',
      'අනතුරක්': 'අනතුරක් (Anathurak - Danger)',
      'beraganna': 'බේරාගන්න (Beraganna - Save Me)',
      'beeraganna': 'බේරාගන්න (Beraganna - Save Me)',
      'save': 'බේරාගන්න (Beraganna - Save Me)',
      'rescue': 'බේරාගන්න (Beraganna - Save Me)',
      'බේරාගන්න': 'බේරාගන්න (Beraganna - Save Me)',
      'ginnak': 'ගින්නක් (Ginnak - Fire)',
      'ginna': 'ගින්නක් (Ginnak - Fire)',
      'fire': 'ගින්නක් (Ginnak - Fire)',
      'burning': 'ගින්නක් (Ginnak - Fire)',
      'ගින්නක්': 'ගින්නක් (Ginnak - Fire)',
      'karadarayak': 'කරදරයක් (Karadarayak - Trouble)',
      'karadara': 'කරදරයක් (Karadarayak - Trouble)',
      'trouble': 'කරදරයක් (Karadarayak - Trouble)',
      'problem': 'කරදරයක් (Karadarayak - Trouble)',
      'කරදරයක්': 'කරදරයක් (Karadarayak - Trouble)',
      'balagena': 'බලාගෙන (Balaagena - Watch Out)',
      'balaagena': 'බලාගෙන (Balaagena - Watch Out)',
      'watch out': 'බලාගෙන (Balaagena - Watch Out)',
      'look out': 'බලාගෙන (Balaagena - Watch Out)',
      'බලාගෙන': 'බලාගෙන (Balaagena - Watch Out)',
      'ehata wenna': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
      'ehatawenna': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
      'ehata': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
      'move aside': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
      'එහාට': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
      'parissamin': 'පරිස්සමින් (Parissamin - Be Careful)',
      'parisamin': 'පරිස්සමින් (Parissamin - Be Careful)',
      'parissamen': 'පරිස්සමින් (Parissamin - Be Careful)',
      'careful': 'පරිස්සමින් (Parissamin - Be Careful)',
      'take care': 'පරිස්සමින් (Parissamin - Be Careful)',

      // Environmental Sounds & Audio Imitations
      'wee-ow': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
      'weeow': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
      'nee-naw': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
      'neenaw': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
      'siren': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
      'ambulance': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
      'සයිරන්': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
      'ගිලන්': 'ගිලන් රථ සයිරන් (Ambulance Siren)',

      'woof-woof': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
      'woofwoof': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
      'woof': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
      'arf-arf': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
      'ruff-ruff': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
      'bark': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
      'barking': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
      'බල්ලා': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
      'බුරනවා': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
      'බුරන': 'බල්ලා බුරන ශබ්දය (Dog Barking)',

      'waa-waa': 'ළදරු හැඬීම (Baby Crying)',
      'waawaa': 'ළදරු හැඬීම (Baby Crying)',
      'wah-wah': 'ළදරු හැඬීම (Baby Crying)',
      'wahwah': 'ළදරු හැඬීම (Baby Crying)',
      'waa': 'ළදරු හැඬීම (Baby Crying)',
      'wah': 'ළදරු හැඬීම (Baby Crying)',
      'crying': 'ළදරු හැඬීම (Baby Crying)',
      'cry': 'ළදරු හැඬීම (Baby Crying)',
      'ළදරු': 'ළදරු හැඬීම (Baby Crying)',
      'හැඬීම': 'ළදරු හැඬීම (Baby Crying)',
      'අඬනවා': 'ළදරු හැඬීම (Baby Crying)',

      'beep-beep': 'වාහන හොන් (Vehicle Horns)',
      'beepbeep': 'වාහන හොන් (Vehicle Horns)',
      'honk-honk': 'වාහන හොන් (Vehicle Horns)',
      'honkhonk': 'වාහන හොන් (Vehicle Horns)',
      'beep': 'වාහන හොන් (Vehicle Horns)',
      'honk': 'වාහන හොන් (Vehicle Horns)',
      'horn': 'වාහන හොන් (Vehicle Horns)',
      'හොන්': 'වාහන හොන් (Vehicle Horns)',
      'පීප්': 'වාහන හොන් (Vehicle Horns)',

      'traffic': 'වාහන තදබදය (Traffic Noise)',
      'vroom': 'වාහන තදබදය (Traffic Noise)',
      'rumble': 'වාහන තදබදය (Traffic Noise)',
      'තදබදය': 'වාහන තදබදය (Traffic Noise)',
      'වාහන': 'වාහන තදබදය (Traffic Noise)',
    };

    for (var entry in wordToSinhala.entries) {
      if (lower.contains(entry.key)) {
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

    final String sanitizedNoHyphen = sanitized.replaceAll('-', ' ');

    if (sanitized.isEmpty) return;

    final Map<String, List<String>> keywordPatterns = {
      'sinhala_udaw_': [
        'udaw', 'udaww', 'udau', 'udawwa', 'udawwak', 'udauwa', 'udav', 'udavv', 'help', 'udawu', 'udauw', 'sos', 'emergency',
        'උදව්', 'උදව්වක්', 'උදවු', 'උදවු කරන්න', 'උදව් කරන්න', 'උදව්ව', 'උදව්ක්'
      ],
      'sinhala_anathurak_': [
        'anathurak', 'anatura', 'anathura', 'anathurai', 'anaturak', 'danger', 'anaturai', 'anathurac', 'accident', 'warning', 'anatur', 'anathur',
        'අනතුරක්', 'අනතුර', 'අනතුරයි'
      ],
      'sinhala_beraganna_': [
        'beraganna', 'beeraganna', 'bcraganna', 'beera', 'beragan', 'save me', 'rescue', 'beragannako', 'berannako',
        'බේරාගන්න', 'බේරගන්න', 'බේරාගන්නකෝ', 'බේරගන්නකෝ', 'බේරන්න'
      ],
      'sinhala_ginnak_': [
        'ginnak', 'ginna', 'ginnaki', 'ginnac', 'fire', 'ginak', 'firefire', 'burning',
        'ගින්නක්', 'ගින්න', 'ගිනි', 'ගිණි'
      ],
      'sinhala_karadarayak_': [
        'karadarayak', 'karadara', 'karadarai', 'karadarayac', 'trouble', 'karadarak', 'problem', 'distress',
        'කරදරයක්', 'කරදර', 'කරදරයි', 'කරදරේ'
      ],
      'sinhala_balagena_': [
        'balagena', 'balagenna', 'balaagena', 'balaganna', 'balang', 'watch out', 'look out', 'caution',
        'බලාගෙන', 'බලන්', 'බලාගෙනම'
      ],
      'sinhala_ehata_wenna_': [
        'ehata wenna', 'ehatawenna', 'ehata', 'move aside', 'move away', 'step back', 'get away',
        'එහාට වෙන්න', 'එහාටවෙන්න', 'එහාට'
      ],
      'sinhala_parissamin_': [
        'parissamin', 'parisamin', 'parissamen', 'parisamen', 'parissam', 'parisam', 'be careful', 'take care',
        'පරිස්සමින්', 'පරිස්සමෙන්', 'පරිසමින්', 'පරිස්සම්'
      ],
      'ambulance': [
        'wee-ow', 'weeow', 'wee ow', 'nee-naw', 'neenaw', 'nee naw', 'siren', 'sirens', 'ambulance', 'ambulance siren', 'wee oo', 'weeoo', 'wail', 'wailing', 'wee', 'ow', 'naw',
        'සයිරන්', 'ගිලන්', 'වී ඕ', 'වීඕ', 'නි නෝ', 'නිනෝ', 'සයිරන් එක', 'ගිලන් රථ'
      ],
      'dog_bark_dataset': [
        'woof-woof', 'woofwoof', 'woof woof', 'arf-arf', 'arfarf', 'arf arf', 'ruff-ruff', 'ruffruff', 'ruff ruff', 'woof', 'woofs', 'arf', 'ruff', 'bark', 'barks', 'barking', 'dog', 'dogs', 'dog barking', 'dog bark', 'yap', 'yapping', 'bow bow', 'bau bau', 'bow', 'bau',
        'බල්ලා', 'බුරනවා', 'බුරන', 'වුෆ්', 'වුෆ් වුෆ්', 'බෝ', 'බෝ බෝ', 'බල්ලන්', 'බල්ලා බුරනවා'
      ],
      'baby crying': [
        'waa-waa', 'waawaa', 'waa waa', 'wah-wah', 'wahwah', 'wah wah', 'waa', 'wah', 'cry', 'crying', 'cries', 'baby', 'babies', 'baby crying', 'baby cry', 'weeping', 'screaming', 'whine', 'whining',
        'ළදරු', 'හැඬීම', 'අඬනවා', 'අඬන', 'වා', 'වා වා', 'වහ්', 'බබා', 'ළමයා', 'ළදරු හැඬීම'
      ],
      'vehicle horns': [
        'beep-beep', 'beepbeep', 'beep beep', 'honk-honk', 'honkhonk', 'honk honk', 'honk', 'honks', 'honking', 'beep', 'beeps', 'beeping', 'toot', 'pip', 'piip', 'car horn', 'vehicle horn', 'horn sound', 'horn', 'horns',
        'හොන්', 'පීප්', 'බීප්', 'බීප් බීප්', 'හොන් එක', 'නාලාව', 'වාහන හොන්'
      ],
      'traffic': [
        'traffic', 'traffic noise', 'road noise', 'car noise', 'vroom', 'rumble', 'street noise', 'highway', 'vehicles', 'තදබදය', 'වාහන', 'පාරේ'
      ],
    };

    final now = DateTime.now();

    for (var entry in keywordPatterns.entries) {
      final key = entry.key;
      for (var pattern in entry.value) {
        if (sanitized.contains(pattern) || sanitizedNoHyphen.contains(pattern)) {
          final lastTime = _lastKeywordTriggerTimes[key];
          if (lastTime == null || now.difference(lastTime).inMilliseconds > 200) {
            _lastKeywordTriggerTimes[key] = now;
            _lastGlobalAlertTime = now;
            final String displayName = _displayNames[key] ?? key;
            _transcriptController.add(displayName);
            simulateSoundDetection(key, confidence: 0.99, overrideCooldown: true);
          }
          return;
        }
      }
    }
  }

  void stopListening() {
    _isListening = false;
    _sttWatchdogTimer?.cancel();
    _sttWatchdogTimer = null;
    _offlineNetCheckTimer?.cancel();
    _offlineNetCheckTimer = null;
    _isOfflineMode = false;
    _latestSoundVolume = 0.02;
    _waveformController.add([]);

    if (_speech.isListening) {
      _speech.stop();
    }
    _pcmStreamSubscription?.cancel();
    _pcmStreamSubscription = null;
    _audioStreamer = null;
    try {
      _pcmRecorder?.stop();
    } catch (_) {}
    _pcmRecorder = null;
    _pendingSinhalaClass = null;
    _pendingSinhalaHits = 0;
    _pendingSinhalaMs = 0;
    _pendingEnvClass = null;
    _pendingEnvHits = 0;
    _pendingEnvMs = 0;
  }

  void debugForceListening() {
    _isListening = true;
    _isOfflineMode = true;
    _hardwareSampleRate = 16000;
  }

  void feedAudioChunk(List<double> chunk) {
    if (!_isListening || _isAnimatingTranscript) return;
    _processPcmBuffer(chunk);
  }

  String debugDetectionState() {
    return _isOfflineMode ? 'offline' : 'online';
  }

  DateTime? _lastEmittedAlertTime;
  final Map<String, DateTime> _lastSoundAlertTimes = {};

  Future<void> simulateSoundDetection(String soundKey, {double confidence = 0.92, bool overrideCooldown = false}) async {
    final now = DateTime.now();

    final lastSoundTime = _lastSoundAlertTimes[soundKey];
    if (lastSoundTime != null && now.difference(lastSoundTime).inMilliseconds < 4000) {
      return;
    }

    if (!overrideCooldown) {
      // 1-second global cooldown for non-override sound detections
      if (_lastEmittedAlertTime != null && now.difference(_lastEmittedAlertTime!).inMilliseconds < 1000) {
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

    // 1. Emit event to UI IMMEDIATELY (0ms Latency for instant alert card popup!)
    _controller.add(event);

    // 2. Trigger Phone Vibration instantly
    VibrationService().triggerVibration(event.priority);

    // 3. Save log to history & sync to Yesido IO 39 smartwatch asynchronously in background
    unawaited(HistoryService().addEvent(event));
    unawaited(SmartwatchService().sendAlertToWatch(event));
  }

  void dispose() {
    stopListening();
    _controller.close();
    _waveformController.close();
    _transcriptController.close();
    _diagController.close();
  }
}

class _SinhalaHit {
  final String className;
  final double probability;
  _SinhalaHit(this.className, this.probability);
}
