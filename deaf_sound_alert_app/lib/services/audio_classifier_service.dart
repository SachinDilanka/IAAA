import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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
  final AudioRecorder _pcmRecorder = AudioRecorder();
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
  DateTime? _lastGlobalAlertTime;

  final Map<String, DateTime> _lastKeywordTriggerTimes = {};
  final Map<String, DateTime> _classCooldown = {};

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

  void _updateWaveformVolume(double newVol) {
    final double targetVol = newVol.clamp(0.18, 1.0);
    if (targetVol > _latestSoundVolume) {
      _latestSoundVolume = targetVol;
    } else {
      _latestSoundVolume = (_latestSoundVolume * 0.65 + targetVol * 0.35).clamp(0.18, 1.0);
    }
  }



  void _safeListenSpeech() async {
    if (!_isListening || _isRestartingStt) return;
    _isRestartingStt = true;

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
      await _speech.cancel();
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 150));
    if (!_isListening) {
      _isRestartingStt = false;
      return;
    }

    try {
      _speechAvailable = await _speech.initialize(
        onError: (val) => _onSpeechError(val.errorMsg),
        onStatus: (val) {
          if ((val == 'done' || val == 'notListening') && _isListening) {
            _onSpeechDone();
          }
        },
      );
    } catch (_) {}

    try {
      final String? targetLocale = (_selectedLocaleId != null && _selectedLocaleId!.isNotEmpty) ? _selectedLocaleId : null;

      await _speech.listen(
        onResult: (result) {
          if (!_isListening) return;
          final String rawWords = result.recognizedWords.trim();
          if (rawWords.isNotEmpty) {
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
          pauseFor: const Duration(seconds: 5),
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
    Timer(const Duration(milliseconds: 200), () {
      if (_isListening && !_speech.isListening && !_isRestartingStt) {
        _safeListenSpeech();
      }
    });
  }

  void _onSpeechError(String errorMsg) {
    if (!_isListening) return;

    final String err = errorMsg.toLowerCase();
    if (err.contains('language') || err.contains('locale') || err.contains('not_supported')) {
      _selectedLocaleId = ""; // Fallback to system default locale
    }

    Timer(const Duration(milliseconds: 250), () {
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
      ].request();
    } catch (_) {}

    _isListening = true;
    _isRestartingStt = false;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _listeningStartTimeMs = nowMs;
    _rollingIdx = 0;
    _total16kPushed = 0;
    _latestSoundVolume = 0.25;

    // 1. Real-Time Speech Recognition Engine for Live Text & Sinhala Streaming
    _safeListenSpeech();

    // 2. Continuous Audio Streamer for PCM Acoustic Neural Inference
    _startAudioStreamer();

    // 4. Heartbeat Watchdog to keep STT active continuously
    _sttWatchdogTimer?.cancel();
    _sttWatchdogTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (_isListening && !_speech.isListening && !_isRestartingStt) {
        _safeListenSpeech();
      }
    });

    return true;
  }

  void _startAudioStreamer() async {
    try {
      _pcmStreamSubscription?.cancel();
      _pcmStreamSubscription = null;

      if (await _pcmRecorder.hasPermission()) {
        final stream = await _pcmRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            numChannels: 1,
            sampleRate: 16000,
          ),
        );

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
            print('PCM Recorder error: $error');
          },
          cancelOnError: false,
        );
      }
    } catch (e) {
      print('PCM Recorder init error: $e');
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
        // Resting baseline: lively micro-bouncing waveform (0.12 - 0.30)
        targetHeight = (0.14 + centerEnvelope * 0.10 + ripple1 + ripple2).clamp(0.12, 0.32);
      } else {
        // Sound / Speech active: energetic response to mic volume and pitch
        final double scaledBand = (bandAmp * 5.0 + soundVol * 0.8).clamp(0.20, 1.0);
        targetHeight = (scaledBand * (centerEnvelope * 0.65 + ripple1 * 0.5 + 0.30)).clamp(0.18, 1.0);
      }
      return targetHeight;
    });

    // Apply smooth exponential moving average across frames for fluid bouncing motion
    for (int i = 0; i < 40; i++) {
      _visualizerBars[i] = _visualizerBars[i] * 0.50 + newFrame[i] * 0.50;
    }

    _waveformController.add(List<double>.from(_visualizerBars));

    // Real-Time Speech & Sinhala Keyword Scanner (Every 200ms when audio input present)
    if (rms > 0.002 || maxAmp > 0.008) {
      if (nowMs - _lastSpeechTimeMs > 200) {
        _lastSpeechTimeMs = nowMs;
        final List<double> speechWindow = List<double>.filled(16000, 0.0);
        for (int i = 0; i < 16000; i++) {
          speechWindow[i] = _rollingBuf16k[(_rollingIdx - 16000 + i + 16000) % 16000];
        }
        final speechPred = _neuralClassifier.predict(speechWindow);
        if (speechPred != null) {
          String? detectedSinhalaKey;
          double bestSinhalaProb = 0.0;

          // Scan top 5 probabilities for any spoken Sinhala emergency word
          speechPred.top5Probabilities.forEach((clsLabel, p) {
            final mapped = _labelToSoundKey[clsLabel] ?? clsLabel;
            if (mapped.startsWith('sinhala_') && p > bestSinhalaProb) {
              bestSinhalaProb = p;
              detectedSinhalaKey = mapped;
            }
          });

          if (detectedSinhalaKey != null && bestSinhalaProb >= 0.15) {
            final displayName = _displayNames[detectedSinhalaKey] ?? detectedSinhalaKey!;
            _transcriptController.add(displayName);
            simulateSoundDetection(detectedSinhalaKey!, confidence: bestSinhalaProb);
          }
        }
      }
    }

    // Continuous Acoustic Neural Inference for BOTH Sinhala Emergency Keywords AND Environmental Sounds (Every 100ms)
    if (_total16kPushed >= 16000 && (nowMs - _listeningStartTimeMs >= 500) && rms > 0.003) {
      if (nowMs - _lastMlTimeMs > 100) {
        _lastMlTimeMs = nowMs;
        _runOfflineNeuralInference(rms);
      }
    }
  }

  void _runOfflineNeuralInference(double rms) {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    // Wait 500ms after mic start to let PCM rolling buffer fully populate and stabilize
    if (nowMs - _listeningStartTimeMs < 500) return;

    // 1.0-Second Cooldown after an alert triggers for unlimited continuous sound detections!
    if (_lastGlobalAlertTime != null && now.difference(_lastGlobalAlertTime!).inMilliseconds < 1000) {
      return;
    }

    // 1.0s window (16,000 samples)
    final List<double> window1s = List<double>.filled(16000, 0.0);
    double winMaxAmp1s = 0.0;
    for (int i = 0; i < 16000; i++) {
      final val = _rollingBuf16k[(_rollingIdx - 16000 + i + 16000) % 16000];
      window1s[i] = val;
      final absV = val.abs();
      if (absV > winMaxAmp1s) winMaxAmp1s = absV;
    }

    // Require real sound amplitude (winMaxAmp1s >= 0.015 and rms >= 0.005) to prevent room silence triggers
    if (winMaxAmp1s < 0.015 || rms < 0.005) return;

    final pred1s = _neuralClassifier.predict(window1s);
    if (pred1s == null) return;

    // Evaluate ONLY the single #1 winning prediction class (NO multiple pop-ups!)
    final topLabel = pred1s.label;
    final topProb = pred1s.probability;
    final soundKey = _labelToSoundKey[topLabel];

    if (soundKey == null) return;

    final bool isSinhala = soundKey.startsWith('sinhala_');
    final double minRequiredProb = isSinhala ? 0.30 : 0.60;

    if (topProb >= minRequiredProb) {
      if (isSinhala) {
        final displayName = _displayNames[soundKey] ?? soundKey;
        _transcriptController.add(displayName);
      }

      simulateSoundDetection(soundKey, confidence: topProb);
    }
  }

  String _formatTranscriptWithSinhala(String rawWords) {
    final String lower = rawWords.toLowerCase();

    final Map<String, String> wordToSinhala = {
      'udaw': 'උදව් (Udaw - Help)',
      'udau': 'උදව් (Udaw - Help)',
      'udaww': 'උදව් (Udaw - Help)',
      'help': 'උදව් (Help - Help)',
      'uda': 'උදව් (Udaw - Help)',
      'උදව්': 'උදව් (Udaw - Help)',
      'උදවු': 'උදව් (Udaw - Help)',
      'anathurak': 'අනතුරක් (Anathurak - Danger)',
      'anatura': 'අනතුරක් (Anathurak - Danger)',
      'danger': 'අනතුරක් (Danger - Danger)',
      'අනතුරක්': 'අනතුරක් (Anathurak - Danger)',
      'beraganna': 'බේරාගන්න (Beraganna - Save Me)',
      'beeraganna': 'බේරාගන්න (Beraganna - Save Me)',
      'save': 'බේරාගන්න (Save Me)',
      'බේරාගන්න': 'බේරාගන්න (Beraganna - Save Me)',
      'ginnak': 'ගින්නක් (Ginnak - Fire)',
      'ginna': 'ගින්නක් (Ginnak - Fire)',
      'fire': 'ගින්නක් (Fire)',
      'ගින්නක්': 'ගින්නක් (Ginnak - Fire)',
      'karadarayak': 'කරදරයක් (Karadarayak - Trouble)',
      'karadara': 'කරදරයක් (Karadarayak - Trouble)',
      'trouble': 'කරදරයක් (Trouble)',
      'කරදරයක්': 'කරදරයක් (Karadarayak - Trouble)',
      'balagena': 'බලාගෙන (Balaagena - Watch Out)',
      'balang': 'බලාගෙන (Balaagena - Watch Out)',
      'watch': 'බලාගෙන (Watch Out)',
      'බලාගෙන': 'බලාගෙන (Balaagena - Watch Out)',
      'ehata wenna': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
      'ehata': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
      'move': 'එහාට වෙන්න (Move Aside)',
      'එහාට': 'එහාට වෙන්න (Ehata Wenna - Move Aside)',
      'parissamin': 'පරිස්සමින් (Parissamin - Be Careful)',
      'parisamin': 'පරිස්සමින් (Parissamin - Be Careful)',
      'careful': 'පරිස්සමින් (Be Careful)',
      'පරිස්සමින්': 'පරිස්සමින් (Be Careful)',
    };

    for (var entry in wordToSinhala.entries) {
      if (lower.contains(entry.key)) {
        return '${entry.value} | $rawWords';
      }
    }

    return rawWords;
  }

  void _processSpeechText(String rawText) {
    final String sanitized = rawText
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'[^\w\s\u0D80-\u0DFF]'), ' ')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (sanitized.isEmpty) return;

    final Map<String, List<String>> keywordPatterns = {
      'sinhala_udaw_': [
        'udaw', 'udaww', 'udau', 'udawwa', 'udawwak', 'udauwa', 'udav', 'udavv', 'help', 'uda', 'udaa', 'udawu', 'udauw', 'sos', 'emergency',
        'උදව්', 'උදව්වක්', 'උදවු', 'උදවු කරන්න', 'උදව් කරන්න', 'උදව්ව', 'උදව්ක්', 'උද'
      ],
      'sinhala_anathurak_': [
        'anathurak', 'anatura', 'anathura', 'anathurai', 'anaturak', 'danger', 'anaturai', 'anathurac', 'accident', 'warning', 'anatu', 'anatur', 'anathur',
        'අනතුරක්', 'අනතුර', 'අනතුරයි'
      ],
      'sinhala_beraganna_': [
        'beraganna', 'beeraganna', 'bcraganna', 'pera', 'beera', 'beragan', 'save', 'beragannako', 'berannako', 'save me', 'rescue', 'bera', 'beera',
        'බේරාගන්න', 'බේරගන්න', 'බේරා', 'බේර', 'බේරන්න', 'බේරාගන්නකෝ', 'බේරගන්නකෝ'
      ],
      'sinhala_ginnak_': [
        'ginnak', 'ginna', 'ginnaki', 'ginnac', 'fire', 'gina', 'ginak', 'firefire', 'burning', 'ginn',
        'ගින්නක්', 'ගින්න', 'ගිනි', 'ගිණි'
      ],
      'sinhala_karadarayak_': [
        'karadarayak', 'karadara', 'karadarai', 'karadarayac', 'trouble', 'karadarak', 'problem', 'distress', 'karadar',
        'කරදරයක්', 'කරදර', 'කරදරයි', 'කරදරේ'
      ],
      'sinhala_balagena_': [
        'balagena', 'balagenna', 'balaagena', 'balaganna', 'balang', 'watch', 'lookout', 'balan', 'watch out', 'look out', 'caution', 'balag',
        'බලාගෙන', 'බලන්', 'බලාගෙනම', 'බලන්න'
      ],
      'sinhala_ehata_wenna_': [
        'ehata', 'wenna', 'ehatawenna', 'move', 'ehata wenna', 'move away', 'step back', 'get away',
        'එහාට', 'වෙන්න', 'එහාටවෙන්න', 'එහාට වෙන්න'
      ],
      'sinhala_parissamin_': [
        'parissamin', 'parisamin', 'parissamen', 'parisamen', 'parissam', 'parisam', 'careful', 'parissamen', 'be careful', 'safe', 'take care', 'pariss', 'paris',
        'පරිස්සමින්', 'පරිස්සමෙන්', 'පරිසමින්', 'පරිස්සම්'
      ],
      'dog_bark_dataset': [
        'bark', 'barking', 'dog barking', 'dog bark', 'woof', 'woof woof', 'barks', 'yap', 'yapping', 'ruff', 'bow', 'bow bow', 'bau', 'bau bau', 'dog', 'dogs', 'බල්ලා', 'බුරන', 'බුරනවා'
      ],
      'baby crying': [
        'crying', 'cry', 'baby crying', 'baby cry', 'waa', 'waaa', 'wee', 'weeping', 'baby', 'cries', 'හැඬීම', 'ළදරු', 'අඬනවා'
      ],
      'ambulance': [
        'siren', 'ambulance', 'ambulance siren', 'alarm', 'wee oo', 'weeoo', 'wail', 'sirens', 'සයිරන්', 'ගිලන්'
      ],
      'vehicle horns': [
        'horn', 'car horn', 'vehicle horn', 'honk', 'honking', 'beep', 'beeping', 'toot', 'pip', 'piip', 'beep beep', 'horn sound', 'honks', 'හොන්', 'හොන් එක', 'පීප්'
      ],
      'traffic': [
        'traffic', 'traffic noise', 'road noise', 'car noise', 'vroom', 'rumble', 'street noise', 'තදබදය', 'වාහන'
      ],
    };

    final now = DateTime.now();

    for (var entry in keywordPatterns.entries) {
      final key = entry.key;
      for (var pattern in entry.value) {
        if (sanitized.contains(pattern)) {
          final lastTime = _lastKeywordTriggerTimes[key];
          if (lastTime == null || now.difference(lastTime).inMilliseconds > 200) {
            _lastKeywordTriggerTimes[key] = now;
            _lastGlobalAlertTime = now;
            simulateSoundDetection(key, confidence: 0.99);
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
    try {
      _pcmRecorder.stop();
    } catch (_) {}
  }

  DateTime? _lastEmittedAlertTime;
  String? _lastEmittedSoundKey;

  Future<void> simulateSoundDetection(String soundKey, {double confidence = 0.92}) async {
    final now = DateTime.now();

    // 1. Strict 2.5-second global cooldown to prevent 4-5 pop-up alert cards!
    if (_lastEmittedAlertTime != null && now.difference(_lastEmittedAlertTime!).inMilliseconds < 2500) {
      return;
    }

    // 2. Strict 4.0-second cooldown for duplicate identical sound alerts
    if (_lastEmittedSoundKey == soundKey && _lastEmittedAlertTime != null && now.difference(_lastEmittedAlertTime!).inMilliseconds < 4000) {
      return;
    }

    final soundConfig = SoundConfigService().getConfig(soundKey);
    if (soundConfig == null || !soundConfig.isEnabled) return;

    _lastEmittedAlertTime = now;
    _lastEmittedSoundKey = soundKey;

    final event = DetectedSound(
      id: now.millisecondsSinceEpoch.toString(),
      soundKey: soundConfig.key,
      soundName: soundConfig.name,
      category: soundConfig.category,
      priority: soundConfig.priority,
      confidence: confidence,
      timestamp: now,
    );

    // Save log
    await HistoryService().addEvent(event);

    // Trigger Phone Vibration
    await VibrationService().triggerVibration(event.priority);

    // Send Alert Push Notification to Android Phone & Smartwatch Yesido IO 39
    await SmartwatchService().sendAlertToWatch(event);

    // Emit single event to UI
    _controller.add(event);
  }

  void dispose() {
    stopListening();
    _controller.close();
    _waveformController.close();
    _transcriptController.close();
  }
}
