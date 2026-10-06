import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_streamer/audio_streamer.dart';
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

  AudioStreamer? _audioStreamer;
  StreamSubscription? _pcmStreamSubscription;

  bool _isListening = false;
  double _latestSoundVolume = 0.02;
  final List<double> _visualizerBars = List<double>.filled(40, 0.15);

  // 16,000 Hz circular rolling audio buffer (1 second = 16,000 samples)
  final List<double> _rollingBuf16k = List<double>.filled(16000, 0.0);
  int _rollingIdx = 0;
  int _total16kPushed = 0;
  int _hardwareSampleRate = 16000;
  int _lastPcmTimeMs = 0;
  int _lastMlTimeMs = 0;
  int _listeningStartTimeMs = 0;

  // Adaptive ambient noise floor tracking (raw mic RMS)
  double _noiseFloor = 0.008;

  // Temporal voting for zero-latency, high-accuracy offline classification
  String? _lastVoteLabel;
  int _voteCount = 0;
  int _lastVoteMs = 0;

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

  // Display names in Sinhala script with English transliteration and meaning
  final Map<String, String> _labelToSinhalaDisplay = {
    'udaw': 'උදව් (Udaw - Help)',
    'beeraganna': 'බේරගන්න (Beraganna - Save Me)',
    'ginnak': 'ගින්නක් (Ginnak - Fire)',
    'anathurak': 'අනතුරක් (Anathurak - Danger)',
    'karadarayak': 'කරදරයක් (Karadarayak - Trouble)',
    'balagena': 'බලාගෙන (Balaagena - Watch Out)',
    'ehata_wenna': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
    'parissamin': 'පරිස්සමින් (Parissamin - Be Careful)',
    'ambulance_siren': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
    'fire_truck': 'ගිනි නිවන රථ ශබ්දය (Fire Truck Siren)',
    'vehicle_horn': 'වාහන හොන් (Vehicle Horns)',
    'baby_crying': 'ළදරු හැඬීම (Baby Crying)',
    'dog_barking': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
    'background_traffic': 'වාහන තදබදය (Traffic Noise)',
  };

  // Maps neural network class names to SoundConfig service keys
  final Map<String, String> _classToSoundKey = {
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

    // Ensure offline neural model is loaded
    if (!_neuralClassifier.isLoaded) {
      await _neuralClassifier.loadModel();
    }

    _isListening = true;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _listeningStartTimeMs = nowMs;
    _rollingIdx = 0;
    _total16kPushed = 0;
    _lastMlTimeMs = 0;
    _latestSoundVolume = 0.25;
    _noiseFloor = 0.008;
    _lastVoteLabel = null;
    _voteCount = 0;

    _startVisualizerTicker();

    _setSttStatus('100% Offline Mode Active (No Internet Needed)');

    // Start continuous hardware microphone stream
    _startAudioStreamer();

    return true;
  }

  void _startAudioStreamer() async {
    try {
      _pcmStreamSubscription?.cancel();
      _pcmStreamSubscription = null;
      _audioStreamer = AudioStreamer();

      _pcmStreamSubscription = _audioStreamer!.audioStream.listen(
        (buffer) {
          if (!_isListening || buffer.isEmpty) return;
          _processPcmBuffer(buffer);
        },
        onError: (error) {
          _setSttStatus('Microphone stream error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      _setSttStatus('Microphone stream initialization error: $e');
    }
  }

  void _processPcmBuffer(List<double> rawBuffer) {
    if (rawBuffer.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // 1. Measure raw peak amplitude
    double maxRaw = 0.0;
    for (int i = 0; i < rawBuffer.length; i++) {
      final a = rawBuffer[i].abs();
      if (a > maxRaw) maxRaw = a;
    }

    // Determine hardware sample rate dynamically
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

    // Normalize 16-bit signed PCM if needed
    final double normScale = maxRaw > 2.0 ? (1.0 / 32768.0) : 1.0;

    // Resample to 16,000 Hz for the neural network
    List<double> packet16k;
    if (_hardwareSampleRate == 16000) {
      packet16k = List<double>.generate(
        rawBuffer.length,
        (i) => (rawBuffer[i] * normScale).clamp(-1.0, 1.0),
      );
    } else {
      final int targetCount =
          ((rawBuffer.length * 16000) / _hardwareSampleRate).round();
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
        double val = count > 0
            ? (sum / count)
            : (rawBuffer[startIdx.clamp(0, rawBuffer.length - 1)] * normScale);
        packet16k[i] = val.clamp(-1.0, 1.0);
      }
    }

    // Push into 16,000 Hz circular rolling buffer
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

    final double rms =
        math.sqrt(sumSquares / (packet16k.isEmpty ? 1 : packet16k.length));

    // Update adaptive background noise floor
    if (rms < _noiseFloor) {
      _noiseFloor = _noiseFloor * 0.90 + rms * 0.10;
    } else {
      _noiseFloor = _noiseFloor * 0.995 + rms * 0.005;
    }

    // Update real-time bouncing wave visualizer
    final double soundVol = (maxAmp * 4.0 + rms * 10.0).clamp(0.04, 1.0);
    _updateWaveformVolume(soundVol);

    // Run Offline Neural Network Inference when sound energy is present
    final bool hasSoundEnergy =
        (rms >= math.max(_noiseFloor * 1.6, 0.005) && maxAmp >= 0.012);
    final bool startupGraceOver = (nowMs - _listeningStartTimeMs >= 300);

    if (_total16kPushed >= 8000 &&
        startupGraceOver &&
        hasSoundEnergy &&
        (nowMs - _lastMlTimeMs >= 100)) {
      _lastMlTimeMs = nowMs;

      // Extract 1-second window
      final List<double> window1s = List<double>.filled(16000, 0.0);
      double windowMax = 0.0;
      for (int i = 0; i < 16000; i++) {
        final s = _rollingBuf16k[(_rollingIdx - 16000 + i + 16000) % 16000];
        window1s[i] = s;
        final absS = s.abs();
        if (absS > windowMax) windowMax = absS;
      }

      // Dynamic peak normalization: ensures distant/far speech (quiet) receives
      // sufficient gain so feature vectors match near speech accurately!
      final List<double> normalizedWindow = List<double>.filled(16000, 0.0);
      final double gain =
          windowMax > 0.005 ? (0.45 / windowMax).clamp(1.0, 10.0) : 1.0;
      for (int i = 0; i < 16000; i++) {
        normalizedWindow[i] = (window1s[i] * gain).clamp(-1.0, 1.0);
      }

      // Run pure Dart offline neural model
      final pred = _neuralClassifier.predict(normalizedWindow);
      if (pred != null) {
        final topLabel = pred.label;
        final topProb = pred.probability;

        // Calculate margin over second-best class
        double secondProb = 0.0;
        for (final e in pred.top5Probabilities.entries) {
          if (e.key != topLabel && e.value > secondProb) {
            secondProb = e.value;
          }
        }
        final double margin = topProb - secondProb;

        const speechClasses = {
          'udaw',
          'beeraganna',
          'ginnak',
          'anathurak',
          'karadarayak',
          'balagena',
          'parissamin',
          'ehata_wenna',
        };

        final bool isSpeech = speechClasses.contains(topLabel);
        final bool confident = isSpeech
            ? (topProb >= 0.48 && margin >= 0.08)
            : (topProb >= 0.58 && margin >= 0.12);

        if (confident) {
          if (_lastVoteLabel == topLabel && (nowMs - _lastVoteMs <= 350)) {
            _voteCount++;
          } else {
            _lastVoteLabel = topLabel;
            _voteCount = 1;
          }
          _lastVoteMs = nowMs;

          // Trigger on 2 consecutive matching frames (~100-200ms) or single high-confidence frame
          final bool shouldTrigger = (_voteCount >= 2) || (topProb >= 0.85);

          if (shouldTrigger) {
            final soundKey = _classToSoundKey[topLabel] ?? topLabel;
            final lastAlert = _lastKeywordTriggerTimes[soundKey];
            final bool cooldownPassed = lastAlert == null ||
                nowMs - lastAlert.millisecondsSinceEpoch >= 1800;

            if (cooldownPassed) {
              _lastKeywordTriggerTimes[soundKey] =
                  DateTime.fromMillisecondsSinceEpoch(nowMs);

              final displayName =
                  _labelToSinhalaDisplay[topLabel] ?? topLabel;

              // 1. Display recognized Sinhala word in the Live Speech box immediately!
              _transcriptController.add(displayName);

              // 2. Pop up emergency alert card immediately!
              simulateSoundDetection(
                soundKey,
                confidence: topProb,
                overrideCooldown: true,
              );
            }
            _voteCount = 0;
          }
        } else {
          if (nowMs - _lastVoteMs > 300) {
            _voteCount = 0;
          }
        }
      }
    }
  }

  void stopListening() {
    _isListening = false;
    _visualizerTicker?.cancel();
    _visualizerTicker = null;
    _latestSoundVolume = 0.02;
    _waveformController.add([]);

    _pcmStreamSubscription?.cancel();
    _pcmStreamSubscription = null;
    _audioStreamer = null;
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

