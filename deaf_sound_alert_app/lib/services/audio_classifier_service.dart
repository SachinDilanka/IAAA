import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audio_streamer/audio_streamer.dart';
import '../models/detected_sound.dart';
import 'vibration_service.dart';
import 'flashlight_service.dart';
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
  StreamSubscription? _pcmStreamSubscription;

  Timer? _sttWatchdogTimer;
  bool _speechAvailable = false;
  String? _selectedLocaleId;
  bool _isListening = false;
  double _latestSoundVolume = 0.02;
  final List<double> _visualizerBars = List<double>.filled(40, 0.15);

  // 16,000 Hz circular rolling audio buffer (1 second)
  final List<double> _rollingBuf16k = List<double>.filled(16000, 0.0);
  int _rollingIdx = 0;
  int _total16kPushed = 0;
  int _hardwareSampleRate = 16000;
  int _lastPcmTimeMs = 0;
  int _lastMlTimeMs = 0;
  int _listeningStartTimeMs = 0;
  int _lastSpeechTimeMs = 0;

  final Map<String, DateTime> _lastKeywordTriggerTimes = {};

  final _controller = StreamController<DetectedSound>.broadcast();
  final _waveformController = StreamController<List<double>>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();

  bool get isListening => _isListening;
  Stream<DetectedSound> get onSoundDetected => _controller.stream;
  Stream<List<double>> get onWaveformUpdated => _waveformController.stream;
  Stream<String> get onTranscriptUpdated => _transcriptController.stream;

  final Map<String, String> _labelToSoundKey = {
    'ambulance_siren': 'ambulance',
    'ambulance': 'ambulance',
    'vehicle_horn': 'vehicle horns',
    'vehicle horns': 'vehicle horns',
    'baby_crying': 'baby crying',
    'baby crying': 'baby crying',
    'dog_barking': 'dog_bark_dataset',
    'dog_bark_dataset': 'dog_bark_dataset',
    'background_traffic': 'traffic',
    'traffic': 'traffic',
    'road': 'road',
    'fire_truck': 'fire_truck',
    'fire_truck_dataset': 'fire_truck',
    'fire_engine': 'fire_truck',
    'fire_siren': 'fire_truck',
    'fire_alarm': 'fire_truck',
    'fire': 'fire_truck',
    'smoke_alarm': 'fire_truck',
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
    'baby crying': 'ළදරු හැඬීම (Baby Crying)',
    'vehicle horns': 'වාහන හොන් (Vehicle Horns)',
    'dog_bark_dataset': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
    'fire_truck': 'ගිනි අනතුරු ඇඟවීම / ගිනි නිවන රථය (Fire Alarm / Siren)',
    'traffic': 'වාහන තදබදය (Traffic Noise)',
    'road': 'පාරේ ශබ්දය (Road Sounds)',
  };

  Future<void> init() async {
    try {
      await _neuralClassifier.loadModel();
    } catch (_) {}

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
          if (!_isListening) return;
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
          listenMode: stt.ListenMode.dictation,
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
      if (!await Permission.microphone.isGranted) {
        await [
          Permission.microphone,
          Permission.notification,
        ].request();
      }
    } catch (_) {}

    _isListening = true;
    _isRestartingStt = false;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _listeningStartTimeMs = nowMs;
    _lastSpeechTimeMs = nowMs;
    _rollingIdx = 0;
    _total16kPushed = 0;
    _latestSoundVolume = 0.25;

    // Start 50 FPS smooth visualizer animation ticker
    _startVisualizerTicker();

    // 1. Continuous Live Speech Engine for transcribing EVERY single word spoken & sound alerts
    _safeListenSpeech();

    // 2. Continuous OFFLINE Pure Dart Neural Audio Streamer
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
          print('AudioStreamer error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('AudioStreamer init error: $e');
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

    // Fast 100ms Neural Inference for Instant 1st-Attempt Speech & Sound Alert Detections!
    if (_total16kPushed >= 2000 && (nowMs - _listeningStartTimeMs >= 200) && (rms >= 0.003 || maxAmp >= 0.008)) {
      if (nowMs - _lastMlTimeMs >= 100) {
        _lastMlTimeMs = nowMs;

        final List<double> window1s = List<double>.filled(16000, 0.0);
        for (int i = 0; i < 16000; i++) {
          window1s[i] = _rollingBuf16k[(_rollingIdx - 16000 + i + 16000) % 16000];
        }

        final pred = _neuralClassifier.predict(window1s);
        if (pred != null) {
          final topLabel = pred.label;
          final topProb = pred.probability;
          final mappedKey = _labelToSoundKey[topLabel] ?? topLabel;

          final double dogProb = pred.allProbabilities['dog_barking'] ?? 0.0;
          final double babyProb = pred.allProbabilities['baby_crying'] ?? 0.0;

          // Compute total speech probability across all speech classes in neural model output
          double totalSpeechProb = 0.0;
          const speechClasses = ['udaw', 'beeraganna', 'ginnak', 'anathurak', 'karadarayak', 'balagena', 'parissamin', 'ehata_wenna'];
          for (var sc in speechClasses) {
            totalSpeechProb += (pred.allProbabilities[sc] ?? 0.0);
          }

          // If speech is detected in acoustic buffer or mapped to Sinhala keyword, mark speech active and do NOT trigger environmental sound cards!
          if (totalSpeechProb >= 0.08 || mappedKey.startsWith('sinhala_')) {
            _lastSpeechTimeMs = nowMs;
            return;
          }

          // ENVIRONMENTAL SOUNDS:
          // Strictly evaluate ONLY when speech has been idle (at least 800ms since last speech)
          // AND total speech probability in model is very low (< 0.06).
          // This prevents ANY human speech (e.g. "karanna", "sinhala words") from triggering environmental sound cards!
          final bool isSpeechIdle = (nowMs - _lastSpeechTimeMs >= 800);
          if (!isSpeechIdle || totalSpeechProb >= 0.06) {
            return;
          }

          // 1. Dog Barking
          if (mappedKey == 'dog_bark_dataset' || dogProb >= 0.70 || topLabel == 'dog_barking') {
            if (math.max(dogProb, topProb) >= 0.70 && (rms >= 0.012 || maxAmp >= 0.035)) {
              final String displayName = _displayNames['dog_bark_dataset'] ?? 'Dog Barking';
              _transcriptController.add(displayName);
              simulateSoundDetection('dog_bark_dataset', confidence: math.max(dogProb, topProb));
              return;
            }
          }

          // 2. Baby Crying (Strict 0.85 threshold so adult human speech vowels like "aa" never falsely trigger it)
          if (mappedKey == 'baby crying' || babyProb >= 0.85 || topLabel == 'baby_crying') {
            if (math.max(babyProb, topProb) >= 0.85 && (rms >= 0.018 || maxAmp >= 0.045)) {
              final String displayName = _displayNames['baby crying'] ?? 'Baby Crying';
              _transcriptController.add(displayName);
              simulateSoundDetection('baby crying', confidence: math.max(babyProb, topProb));
              return;
            }
          }

          // 3. Ambulance Siren
          if (mappedKey == 'ambulance' || topLabel == 'ambulance_siren') {
            if (topProb >= 0.68 && (rms >= 0.015 || maxAmp >= 0.040)) {
              final String displayName = _displayNames['ambulance'] ?? 'Ambulance Siren';
              _transcriptController.add(displayName);
              simulateSoundDetection('ambulance', confidence: topProb);
              return;
            }
          }

          // 4. Fire Truck Siren / Fire Alarm
          if (mappedKey == 'fire_truck' || topLabel == 'fire_truck' || topLabel == 'fire_alarm' || topLabel == 'fire_engine' || topLabel == 'fire_siren') {
            if (topProb >= 0.65 && (rms >= 0.015 || maxAmp >= 0.040)) {
              final String displayName = _displayNames['fire_truck'] ?? 'Fire Alarm / Siren';
              _transcriptController.add(displayName);
              simulateSoundDetection('fire_truck', confidence: topProb);
              return;
            }
          }

          // 5. Vehicle Horns
          if (mappedKey == 'vehicle horns' || topLabel == 'vehicle_horn') {
            if (topProb >= 0.70 && (rms >= 0.018 || maxAmp >= 0.045)) {
              final String displayName = _displayNames['vehicle horns'] ?? 'Vehicle Horns';
              _transcriptController.add(displayName);
              simulateSoundDetection('vehicle horns', confidence: topProb);
              return;
            }
          }

          // 6. Traffic Noise
          if (mappedKey == 'traffic' || topLabel == 'background_traffic') {
            if (topProb >= 0.65 && (rms >= 0.015 || maxAmp >= 0.035)) {
              final String displayName = _displayNames['traffic'] ?? 'Traffic Noise';
              _transcriptController.add(displayName);
              simulateSoundDetection('traffic', confidence: topProb);
              return;
            }
          }
        }
      }
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
    };

    final now = DateTime.now();

    for (var entry in keywordPatterns.entries) {
      final key = entry.key;
      for (var pattern in entry.value) {
        if (sanitized.contains(pattern) || sanitizedNoHyphen.contains(pattern)) {
          final lastTime = _lastKeywordTriggerTimes[key];
          if (lastTime == null || now.difference(lastTime).inMilliseconds > 200) {
            _lastKeywordTriggerTimes[key] = now;
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
    _latestSoundVolume = 0.02;
    _waveformController.add([]);

    if (_speech.isListening) {
      _speech.stop();
    }
    _pcmStreamSubscription?.cancel();
    _pcmStreamSubscription = null;
    _audioStreamer = null;
    FlashlightService().cancelFlashlight();
  }

  DateTime? _lastEmittedAlertTime;
  final Map<String, DateTime> _lastSoundAlertTimes = {};

  Future<void> simulateSoundDetection(String soundKey, {double confidence = 0.92, bool overrideCooldown = false}) async {
    final now = DateTime.now();

    if (!overrideCooldown) {
      final lastSoundTime = _lastSoundAlertTimes[soundKey];
      if (lastSoundTime != null && now.difference(lastSoundTime).inMilliseconds < 2500) {
        return;
      }
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

    // 3. Trigger Flashlight Flashing pattern based on priority level
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
  }
}
