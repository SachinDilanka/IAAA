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
  int _lastKeywordFiredMs = 0;

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
    _lastKeywordFiredMs = 0;
    _rollingIdx = 0;
    _total16kPushed = 0;
    _lastMlTimeMs = 0;
    _pendingEnvironmentSound = null;
    _pendingEnvironmentVotes = 0;
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

    // Filter out pure silence while accepting far and quiet speech (MaxAmp >= 0.0030 or RMS >= 0.0008)
    final bool hasSoundEnergy = (maxAmp >= 0.0030 || rms >= 0.0008);
    final bool startupGraceOver = (nowMs - _listeningStartTimeMs >= 1000);

    // Require full 16,000 samples (1.0 full second) in buffer before running classification
    if (_total16kPushed >= 16000 &&
        startupGraceOver &&
        hasSoundEnergy &&
        (nowMs - _lastMlTimeMs >= 140)) {
      _lastMlTimeMs = nowMs;

      // Extract unrolled 16,000 samples (1.0 second)
      final List<double> window16k = List<double>.filled(16000, 0.0);
      double windowMax = 0.0;
      double windowSumSq = 0.0;
      for (int i = 0; i < 16000; i++) {
        final s = _rollingBuf16k[(_rollingIdx - 16000 + i + 16000) % 16000];
        window16k[i] = s;
        final absS = s.abs();
        if (absS > windowMax) windowMax = absS;
        windowSumSq += absS * absS;
      }
      final double windowRms = math.sqrt(windowSumSq / 16000);

      // Gate out electronic silence floor
      if (windowMax < 0.0025 && windowRms < 0.0007) {
        _pendingEnvironmentSound = null;
        _pendingEnvironmentVotes = 0;
        return;
      }

      // Dynamic gain normalization for near & far speech
      final double gain =
          windowMax > 0.0002 ? (0.50 / windowMax).clamp(1.0, 40.0) : 1.0;
      final List<double> normWindow = List<double>.filled(16000, 0.0);
      for (int i = 0; i < 16000; i++) {
        normWindow[i] = (window16k[i] * gain).clamp(-1.0, 1.0);
      }

      final pred = _neuralClassifier.predict(normWindow);
      if (pred == null) return;
      final allP = pred.allProbabilities;

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

      // Find top Sinhala speech class
      String? topSpeechClass;
      double topSpeechProb = 0.0;
      for (final s in speechClasses) {
        final p = allP[s] ?? 0.0;
        if (p > topSpeechProb) {
          topSpeechProb = p;
          topSpeechClass = s;
        }
      }

      // Find top environmental class
      String? topEnvClass;
      double topEnvProb = 0.0;
      for (final e in envSoundMap.keys) {
        final p = allP[e] ?? 0.0;
        if (p > topEnvProb) {
          topEnvProb = p;
          topEnvClass = e;
        }
      }

      // Decision: Is this Sinhala speech?
      final bool isSpeech = topSpeechClass != null &&
          topSpeechProb >= 0.35 &&
          topSpeechProb >= topEnvProb * 0.65;

      if (isSpeech) {
        _lastSpeechTimeMs = nowMs;
        _pendingEnvironmentSound = null;
        _pendingEnvironmentVotes = 0;

        // Trigger keyword with a 2.0-second cooldown to prevent double-triggering or tail noise
        if (nowMs - _lastKeywordFiredMs >= 2000) {
          _lastKeywordFiredMs = nowMs;
          final soundKey = _classToSoundKey[topSpeechClass];
          if (soundKey != null) {
            final displayText =
                _sinhalaLiveSpeechWord[soundKey] ?? topSpeechClass;
            _transcriptController.add(displayText);
            unawaited(simulateSoundDetection(
              soundKey,
              confidence: topSpeechProb,
              overrideCooldown: true,
            ));
          }
        }
        return; // ABSOLUTE STOP! User speech NEVER triggers environmental sounds!
      }

      // Environmental sounds branch:
      // STRICT conditions:
      // 1. User has NOT spoken for at least 6.0 seconds
      // 2. Real acoustic volume (sirens, car horns, dog barking, baby crying):
      //    windowMax >= 0.08 and windowRms >= 0.012 (prevents room noise/breathing from ever triggering sirens!)
      // 3. Speech probability is negligible (< 0.20)
      // 4. High sustained confidence (>= 0.75)
      // 5. Requires multiple consecutive voting windows (~700ms) of sustained siren/sound
      final bool userSpokeRecently = (nowMs - _lastSpeechTimeMs < 6000);
      final bool hasRealEmergencyEnergy = (windowMax >= 0.08 && windowRms >= 0.012);

      if (!userSpokeRecently &&
          hasRealEmergencyEnergy &&
          topSpeechProb < 0.20 &&
          topEnvClass != null &&
          topEnvProb >= 0.75) {
        final candidateSound = envSoundMap[topEnvClass];
        if (candidateSound != null) {
          final bool trafficValid = (topEnvClass != 'background_traffic') ||
              (topEnvProb >= 0.88 && windowRms >= 0.035 && windowMax >= 0.15);

          if (trafficValid) {
            if (_pendingEnvironmentSound == candidateSound) {
              _pendingEnvironmentVotes++;
            } else {
              _pendingEnvironmentSound = candidateSound;
              _pendingEnvironmentVotes = 1;
            }

            final int reqVotes = (topEnvProb >= 0.90) ? 4 : 5;
            if (_pendingEnvironmentVotes >= reqVotes) {
              _pendingEnvironmentVotes = 0;
              simulateSoundDetection(candidateSound, confidence: topEnvProb);
            }
          } else {
            _pendingEnvironmentVotes = 0;
          }
        }
      } else {
        _pendingEnvironmentVotes = 0;
        _pendingEnvironmentSound = null;
      }
    }
  }



  void stopListening() {
    _isListening = false;
    _visualizerTicker?.cancel();
    _visualizerTicker = null;
    _latestSoundVolume = 0.02;
    _waveformController.add([]);

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
