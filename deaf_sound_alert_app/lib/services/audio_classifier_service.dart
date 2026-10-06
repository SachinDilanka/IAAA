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
  int _lastSpeechTimeMs = 0;

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

  // Exact Live Speech display strings for 8 Sinhala emergency keywords
  static final Map<String, String> _sinhalaLiveSpeechDisplay = {
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
  static final Map<String, String> _envLiveSpeechDisplay = {
    'ambulance': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
    'fire_truck': 'ගිනි නිවන රථ ශබ්දය (Fire Truck Siren)',
    'vehicle horns': 'වාහන හොන් (Vehicle Horns)',
    'baby crying': 'ළදරු හැඬීම (Baby Crying)',
    'dog_bark_dataset': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
    'traffic': 'වාහන තදබදය (Traffic Noise)',
  };

  static final Map<String, String> _classToLiveSpeechDisplay = {
    'udaw': 'udaw  →  උදව් (Udaw - Help)',
    'beeraganna': 'beeraganna  →  බේරගන්න (Beraganna - Save Me)',
    'ginnak': 'ginnak  →  ගින්නක් (Ginnak - Fire)',
    'anathurak': 'anathurak  →  අනතුරක් (Anathurak - Danger)',
    'karadarayak': 'karadarayak  →  කරදරයක් (Karadarayak - Trouble)',
    'balagena': 'balagena  →  බලාගෙන (Balaagena - Watch Out)',
    'ehata_wenna': 'ehata wenna  →  එහාට වෙන්න (Ehata Wenna - Move Aside)',
    'parissamin': 'parissamin  →  පරිස්සමින් (Parissamin - Be Careful)',
    'ambulance_siren': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
    'fire_truck': 'ගිනි නිවන රථ ශබ්දය (Fire Truck Siren)',
    'vehicle_horn': 'වාහන හොන් (Vehicle Horns)',
    'baby_crying': 'ළදරු හැඬීම (Baby Crying)',
    'dog_barking': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
    'background_traffic': 'වාහන තදබදය (Traffic Noise)',
  };

  static final Map<String, String> _classToSoundKey = {
    'udaw': 'sinhala_udaw_',
    'beeraganna': 'sinhala_beraganna_',
    'ginnak': 'sinhala_ginnak_',
    'anathurak': 'sinhala_anathurak_',
    'karadarayak': 'sinhala_karadarayak_',
    'balagena': 'sinhala_balagena_',
    'ehata_wenna': 'sinhala_ehata_wenna_',
    'parissamin': 'sinhala_parissamin_',
    'ambulance_siren': 'ambulance',
    'fire_truck': 'fire_truck',
    'vehicle_horn': 'vehicle horns',
    'baby_crying': 'baby crying',
    'dog_barking': 'dog_bark_dataset',
    'background_traffic': 'traffic',
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
    _rollingIdx = 0;
    _total16kPushed = 0;
    _lastMlTimeMs = 0;
    _latestSoundVolume = 0.25;
    _rollingBuf16k.fillRange(0, 16000, 0.0);

    _startVisualizerTicker();

    _setSttStatus('100% Offline Deep Audio Awareness Active (Zero Internet)');

    await _startSpeechRecognition();

    // Start 100% offline native 16kHz audio stream via AudioRecorder
    _startAudioCapture();

    return true;
  }

  Future<void> _startSpeechRecognition() async {
    try {
      await _speechSubscription?.cancel();
      _speechSubscription = _speechEvents.receiveBroadcastStream().listen(
        (event) {
          if (!_isListening || event is! Map) return;
          final type = event['type']?.toString();
          final text = event['text']?.toString().trim() ?? '';
          if ((type == 'partialResult' || type == 'finalResult') &&
              text.isNotEmpty) {
            _lastSpeechTimeMs = DateTime.now().millisecondsSinceEpoch;
            _setSttStatus('Live offline speech active (English)');
            _processSpeechText(text);
          } else if (type == 'error') {
            _setSttStatus(
                'Speech recognizer error: ${event['text'] ?? 'unknown'}');
          }
        },
        onError: (Object error) {
          if (_isListening) {
            _setSttStatus('Speech recognizer error: $error');
          }
        },
      );

      final available =
          await _speechChannel.invokeMethod<bool>('isAvailable') ?? false;
      if (!available) {
        _setSttStatus('Android speech recognizer is unavailable.');
        return;
      }
      await _speechChannel.invokeMethod('startListening');
      _setSttStatus(
          'Listening offline English. Say udaw, ginnak, or another keyword.');
    } catch (error) {
      _setSttStatus('Could not start speech recognition: $error');
    }
  }

  void _processSpeechText(String rawText) {
    final text = rawText
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) return;

    const keywords = <String, String>{
      'udaw': 'sinhala_udaw_',
      'udau': 'sinhala_udaw_',
      'udav': 'sinhala_udaw_',
      'help': 'sinhala_udaw_',
      'උදව්': 'sinhala_udaw_',
      'උදවු': 'sinhala_udaw_',
      'beeraganna': 'sinhala_beraganna_',
      'beraganna': 'sinhala_beraganna_',
      'rescue': 'sinhala_beraganna_',
      'save me': 'sinhala_beraganna_',
      'බේරගන්න': 'sinhala_beraganna_',
      'බේරාගන්න': 'sinhala_beraganna_',
      'ginnak': 'sinhala_ginnak_',
      'ginna': 'sinhala_ginnak_',
      'fire': 'sinhala_ginnak_',
      'ගින්නක්': 'sinhala_ginnak_',
      'ගින්න': 'sinhala_ginnak_',
      'anathurak': 'sinhala_anathurak_',
      'anaturak': 'sinhala_anathurak_',
      'danger': 'sinhala_anathurak_',
      'අනතුරක්': 'sinhala_anathurak_',
      'අනතුර': 'sinhala_anathurak_',
      'karadarayak': 'sinhala_karadarayak_',
      'karadara': 'sinhala_karadarayak_',
      'trouble': 'sinhala_karadarayak_',
      'කරදරයක්': 'sinhala_karadarayak_',
      'කරදර': 'sinhala_karadarayak_',
      'balagena': 'sinhala_balagena_',
      'balaagena': 'sinhala_balagena_',
      'watch out': 'sinhala_balagena_',
      'බලාගෙන': 'sinhala_balagena_',
      'ehata wenna': 'sinhala_ehata_wenna_',
      'ehatawenna': 'sinhala_ehata_wenna_',
      'move aside': 'sinhala_ehata_wenna_',
      'එහාට වෙන්න': 'sinhala_ehata_wenna_',
      'parissamin': 'sinhala_parissamin_',
      'parissamen': 'sinhala_parissamin_',
      'be careful': 'sinhala_parissamin_',
      'careful': 'sinhala_parissamin_',
      'පරිස්සමින්': 'sinhala_parissamin_',
    };

    _transcriptController.add(rawText);
    for (final entry in keywords.entries) {
      if (!text.contains(entry.key)) continue;
      final now = DateTime.now();
      final previous = _lastKeywordTriggerTimes[entry.value];
      if (previous != null &&
          now.difference(previous).inMilliseconds < 1800) {
        return;
      }
      _lastKeywordTriggerTimes[entry.value] = now;
      _transcriptController.add(
          _sinhalaLiveSpeechDisplay[entry.value] ?? rawText);
      unawaited(simulateSoundDetection(
        entry.value,
        confidence: 0.99,
        overrideCooldown: true,
      ));
      return;
    }
  }

  void _startAudioCapture() async {
    try {
      _recordStreamSub?.cancel();
      _audioRecorder?.dispose();
      _audioRecorder = AudioRecorder();

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
    } catch (e) {
      _setSttStatus('Audio stream init error: $e');
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

    // Filter out silence and ambient room noise (Real speech / audio has MaxAmp >= 0.035 or RMS >= 0.012)
    final bool hasSoundEnergy = (maxAmp >= 0.035 || rms >= 0.012);
    final bool startupGraceOver = (nowMs - _listeningStartTimeMs >= 350);

    if (_total16kPushed >= 8000 &&
        startupGraceOver &&
        hasSoundEnergy &&
        (nowMs - _lastMlTimeMs >= 100)) {
      _lastMlTimeMs = nowMs;

      // Extract 1-second rolling window
      final List<double> window1s = List<double>.filled(16000, 0.0);
      double windowMax = 0.0;
      for (int i = 0; i < 16000; i++) {
        final s = _rollingBuf16k[(_rollingIdx - 16000 + i + 16000) % 16000];
        window1s[i] = s;
        final absS = s.abs();
        if (absS > windowMax) windowMax = absS;
      }

      // Dynamic Automatic Gain Control (AGC) up to 30x for far speech or sounds
      final List<double> normalizedWindow = List<double>.filled(16000, 0.0);
      final double gain =
          windowMax > 0.001 ? (0.60 / windowMax).clamp(1.0, 30.0) : 1.0;
      for (int i = 0; i < 16000; i++) {
        normalizedWindow[i] = (window1s[i] * gain).clamp(-1.0, 1.0);
      }

      // Run 100% offline pure-Dart neural network
      final pred = _neuralClassifier.predict(normalizedWindow);
      if (pred != null) {
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
        String? bestSpeechClass;
        double bestSpeechProb = 0.0;
        for (final s in speechClasses) {
          final p = allP[s] ?? 0.0;
          if (p > bestSpeechProb) {
            bestSpeechProb = p;
            bestSpeechClass = s;
          }
        }

        // Find top environmental class
        String? bestEnvClass;
        double bestEnvProb = 0.0;
        for (final e in envSoundMap.keys) {
          final p = allP[e] ?? 0.0;
          if (p > bestEnvProb) {
            bestEnvProb = p;
            bestEnvClass = e;
          }
        }

        // === DECISION ENGINE ===
        // Case A: Sinhala Speech Keyword Detected (ABSOLUTE PRIORITY OVER ENVIRONMENTAL SOUNDS)
        if (bestSpeechClass != null &&
            bestSpeechProb >= 0.40 &&
            bestSpeechProb >= bestEnvProb * 0.70) {
          final soundKey = _classToSoundKey[bestSpeechClass] ?? bestSpeechClass;
          final lastAlert = _lastKeywordTriggerTimes[soundKey];
          final bool cooldownPassed = lastAlert == null ||
              nowMs - lastAlert.millisecondsSinceEpoch >= 1800;

          if (cooldownPassed) {
            _lastKeywordTriggerTimes[soundKey] =
                DateTime.fromMillisecondsSinceEpoch(nowMs);
            _lastSpeechTimeMs = nowMs;

            final display = _sinhalaLiveSpeechDisplay[soundKey] ??
                _classToLiveSpeechDisplay[bestSpeechClass] ??
                bestSpeechClass;

            // 1. Display recognized Sinhala word in the Live Speech box FIRST
            _transcriptController.add(display);

            // 2. Pop up the matching Sinhala emergency card IMMEDIATELY
            simulateSoundDetection(
              soundKey,
              confidence: bestSpeechProb,
              overrideCooldown: true,
            );
          }
          return; // STOP! User voice NEVER triggers environmental sounds!
        }

        // Case B: Background Environmental Sound (Ambulance, Fire Truck, Horn, Dog, Baby, Traffic)
        // Only evaluated when user is NOT speaking (no speech within last 2.5 seconds)
        final bool userSpokeRecently = (nowMs - _lastSpeechTimeMs < 2500);

        if (!userSpokeRecently && bestEnvClass != null) {
          final soundKey = envSoundMap[bestEnvClass];
          const envThresholds = {
            'ambulance_siren': 0.65,
            'fire_truck': 0.65,
            'vehicle_horn': 0.65,
            'baby_crying': 0.65,
            'dog_barking': 0.65,
            'background_traffic': 0.88,
          };
          final double requiredProb = envThresholds[bestEnvClass] ?? 0.70;

          // Traffic requires loud real audio (rms >= 0.035, maxAmp >= 0.15), NEVER silence/noise!
          final bool trafficValid = (bestEnvClass != 'background_traffic') ||
              (rms >= 0.035 && maxAmp >= 0.15);

          if (soundKey != null &&
              bestEnvProb >= requiredProb &&
              bestSpeechProb < 0.25 &&
              trafficValid) {
            final lastAlert = _lastSoundAlertTimes[soundKey];
            final bool cooldownPassed = lastAlert == null ||
                nowMs - lastAlert.millisecondsSinceEpoch >= 2500;

            if (cooldownPassed) {
              final display = _envLiveSpeechDisplay[soundKey] ??
                  _classToLiveSpeechDisplay[bestEnvClass] ??
                  bestEnvClass;

              // 1. Display detected environmental sound in Live Speech box
              _transcriptController.add(display);

              // 2. Pop up ONLY that specific environmental sound card!
              simulateSoundDetection(soundKey, confidence: bestEnvProb);
            }
          }
        }
      }
    }
  }

  void stopListening() {
    _isListening = false;
    _visualizerTicker?.cancel();
    _visualizerTicker = null;
    _speechSubscription?.cancel();
    _speechSubscription = null;
    _speechChannel.invokeMethod('stopListening');
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
