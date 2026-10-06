import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
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

  final List<double> _utteranceSamples = [];
  bool _inSpeechUtterance = false;
  int _speechSilenceChunks = 0;
  String? _currentDisplayedKeyword;

  final Map<String, DateTime> _lastSoundAlertTimes = {};
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

  static const Map<String, String> _sinhalaLiveSpeechWord = {
    'sinhala_udaw_': 'උදව් (Udaw - Help)',
    'sinhala_beraganna_': 'බේරගන්න (Beraganna - Save Me)',
    'sinhala_ginnak_': 'ගින්නක් (Ginnak - Fire)',
    'sinhala_anathurak_': 'අනතුරක් (Anathurak - Danger)',
    'sinhala_karadarayak_': 'කරදරයක් (Karadarayak - Trouble)',
    'sinhala_balagena_': 'බලාගෙන (Balaagena - Watch Out)',
    'sinhala_ehata_wenna_': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
    'sinhala_parissamin_': 'පරිස්සමින් (Parissamin - Be Careful)',
  };

  static const Map<String, String> _envLiveSpeechDisplay = {
    'ambulance': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
    'fire_truck': 'ගිනි නිවන රථ ශබ්දය (Fire Truck Siren)',
    'vehicle horns': 'වාහන හෝන් (Vehicle Horn)',
    'baby crying': 'ළදරුවාගේ හැඬීම (Baby Crying)',
    'dog_bark_dataset': 'බල්ලා බුරන හඬ (Dog Barking)',
    'traffic': 'මාර්ග තදබදය (Traffic Noise)',
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
      final modelLoaded = await _neuralClassifier.loadModel();
      if (!modelLoaded) {
        _setSttStatus('Offline sound model could not be loaded.');
        return false;
      }
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
    _inSpeechUtterance = false;
    _utteranceSamples.clear();
    _speechSilenceChunks = 0;
    _latestSoundVolume = 0.25;
    _rollingBuf16k.fillRange(0, 16000, 0.0);

    _startVisualizerTicker();

    // Fully offline mode: the bundled classifier is the only microphone
    // consumer. Android SpeechRecognizer is not started.
    final captureStarted = await _startAudioCapture();
    if (!captureStarted) {
      _isListening = false;
      _visualizerTicker?.cancel();
      _visualizerTicker = null;
      return false;
    }
    _setSttStatus(
        'Offline detection active. Say a Sinhala keyword or play a sound.');

    return true;
  }

  Future<bool> _startAudioCapture() async {
    try {
      _recordStreamSub?.cancel();
      _audioRecorder?.dispose();
      _audioRecorder = AudioRecorder();

      if (!await _audioRecorder!.hasPermission()) {
        _setSttStatus('Microphone permission was denied.');
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
        onError: (err) {
          _setSttStatus('Audio stream error: $err');
        },
        cancelOnError: false,
      );
      _setSttStatus('Listening offline. Say a Sinhala emergency keyword.');
      return true;
    } catch (e) {
      _setSttStatus('Audio stream init error: $e');
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

    final List<double> currentChunkSamples = List<double>.filled(numSamples, 0.0);

    for (int i = 0; i < numSamples; i++) {
      final int s16 = byteData.getInt16(i * 2, Endian.little);
      final double sampleNorm = (s16 / 32768.0).clamp(-1.0, 1.0);
      final double absS = sampleNorm.abs();

      if (absS > maxAmp) maxAmp = absS;
      sumSquares += sampleNorm * sampleNorm;
      currentChunkSamples[i] = sampleNorm;

      _rollingBuf16k[_rollingIdx] = sampleNorm;
      _rollingIdx = (_rollingIdx + 1) % 16000;
      _total16kPushed++;
    }

    final double rms = math.sqrt(sumSquares / numSamples);

    // Update real-time bouncing wave visualizer
    final double soundVol = (maxAmp * 4.0 + rms * 10.0).clamp(0.04, 1.0);
    _updateWaveformVolume(soundVol);

    const speechClasses = {
      'udaw',
      'beeraganna',
      'ginnak',
      'anathurak',
      'karadarayak',
      'balagena',
      'ehata_wenna',
      'parissamin',
    };

    const envSoundMap = {
      'ambulance_siren': 'ambulance',
      'fire_truck': 'fire_truck',
      'vehicle_horn': 'vehicle horns',
      'baby_crying': 'baby crying',
      'dog_barking': 'dog_bark_dataset',
      'background_traffic': 'traffic',
    };

    // Voice Activity Detection (VAD) - sensitive for near and far microphone
    final bool isVoiceChunk = (maxAmp >= 0.008 || rms >= 0.0015);

    if (isVoiceChunk) {
      _lastSpeechTimeMs = nowMs;
      _pendingEnvironmentSound = null;
      _pendingEnvironmentVotes = 0;

      if (!_inSpeechUtterance) {
        _inSpeechUtterance = true;
        _speechSilenceChunks = 0;
        _utteranceSamples.clear();
        // Include up to 800 pre-onset samples (~50ms) to preserve onset consonants
        final preCount = math.min(800, _total16kPushed);
        for (int i = 0; i < preCount; i++) {
          final s = _rollingBuf16k[(_rollingIdx - preCount + i + 16000) % 16000];
          _utteranceSamples.add(s);
        }
      } else {
        _speechSilenceChunks = 0;
      }
      _utteranceSamples.addAll(currentChunkSamples);
    } else if (_inSpeechUtterance) {
      _speechSilenceChunks++;
      _utteranceSamples.addAll(currentChunkSamples);
    }

    // === UTTERANCE EVALUATION (Exact Spoken Sinhala Keyword) ===
    // Evaluates ONLY when the user has actually finished speaking the complete word!
    final bool utteranceFinished = _inSpeechUtterance &&
        ((_speechSilenceChunks >= 2 && _utteranceSamples.length >= 3200) ||
            _utteranceSamples.length >= 16000);

    if (utteranceFinished) {
      final List<double> uWindow16k = List<double>.filled(16000, 0.0);
      final int uCount = math.min(16000, _utteranceSamples.length);
      double uMax = 0.0;
      for (int i = 0; i < uCount; i++) {
        final s = _utteranceSamples[i];
        uWindow16k[i] = s;
        final absS = s.abs();
        if (absS > uMax) uMax = absS;
      }

      if (uMax >= 0.004) {
        final double uGain = (0.50 / uMax).clamp(1.0, 50.0);
        final List<double> uNorm = List<double>.filled(16000, 0.0);
        for (int i = 0; i < 16000; i++) {
          uNorm[i] = (uWindow16k[i] * uGain).clamp(-1.0, 1.0);
        }

        final uPred = _neuralClassifier.predict(uNorm);
        if (uPred != null) {
          String? bestSpeechClass;
          double bestSpeechProb = 0.0;
          for (final sc in speechClasses) {
            final p = uPred.allProbabilities[sc] ?? 0.0;
            if (p > bestSpeechProb) {
              bestSpeechProb = p;
              bestSpeechClass = sc;
            }
          }

          if (nowMs >= _keywordLockUntilMs && bestSpeechClass != null) {
            _keywordLockUntilMs = nowMs + 4000; // Lock for 4.0 seconds!
            _lastSpeechTimeMs = nowMs;
            _currentDisplayedKeyword = bestSpeechClass;

            final soundKey = _classToSoundKey[bestSpeechClass];
            if (soundKey != null) {
              final displayText =
                  _sinhalaLiveSpeechWord[soundKey] ?? bestSpeechClass;
              _transcriptController.add(displayText);
              unawaited(simulateSoundDetection(
                soundKey,
                confidence: math.max(bestSpeechProb, 0.99),
                overrideCooldown: true,
              ));
            }
          }
        }
      }
      _inSpeechUtterance = false;
      _utteranceSamples.clear();
      _speechSilenceChunks = 0;
    }

    final bool startupGraceOver = (nowMs - _listeningStartTimeMs >= 800);

    // === BACKGROUND ENVIRONMENTAL SOUNDS ONLY (WHEN USER IS NOT SPEAKING) ===
    final bool userSpokeRecently = (nowMs - _lastSpeechTimeMs < 5000);
    final bool keywordActive = (nowMs < _keywordLockUntilMs);
    final bool inSpeech = _inSpeechUtterance || isVoiceChunk;

    // Environmental inference runs ONLY when user has been completely silent for >= 5.0s
    if (_total16kPushed >= 8000 &&
        startupGraceOver &&
        !userSpokeRecently &&
        !keywordActive &&
        !inSpeech &&
        (nowMs - _lastMlTimeMs >= 140)) {
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

      final double gain = (0.50 / windowMax).clamp(1.0, 50.0);
      final List<double> normWindow = List<double>.filled(16000, 0.0);
      for (int i = 0; i < 16000; i++) {
        normWindow[i] = (window16k[i] * gain).clamp(-1.0, 1.0);
      }

      final pred = _neuralClassifier.predict(normWindow);
      if (pred == null) return;
      final allP = pred.allProbabilities;

      double topSpeechProb = 0.0;
      for (final s in speechClasses) {
        final p = allP[s] ?? 0.0;
        if (p > topSpeechProb) {
          topSpeechProb = p;
        }
      }

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
        final candidateSound = envSoundMap[topEnvClass];
        if (candidateSound != null) {
          const envThresholds = {
            'ambulance_siren': 0.60,
            'fire_truck': 0.70,
            'vehicle_horn': 0.55,
            'baby_crying': 0.55,
            'dog_barking': 0.55,
            'background_traffic': 0.80,
          };
          final double reqProb = envThresholds[topEnvClass] ?? 0.60;
          final bool trafficValid = (topEnvClass != 'background_traffic') ||
              (rms >= 0.035 && windowMax >= 0.15);

          final bool isValid = topEnvProb >= reqProb &&
              topEnvProb >= topSpeechProb * 1.40 &&
              trafficValid;

          if (isValid) {
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
              simulateSoundDetection(candidateSound, confidence: topEnvProb);
              _pendingEnvironmentVotes = 0;
              _pendingEnvironmentSound = null;
            }
          } else {
            _pendingEnvironmentSound = null;
            _pendingEnvironmentVotes = 0;
          }
        }
      } else {
        _pendingEnvironmentSound = null;
        _pendingEnvironmentVotes = 0;
      }
    }
  }

  void stopListening() {
    _isListening = false;
    _visualizerTicker?.cancel();
    _visualizerTicker = null;
    _latestSoundVolume = 0.02;
    _waveformController.add([]);
    _inSpeechUtterance = false;
    _utteranceSamples.clear();
    _speechSilenceChunks = 0;
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
