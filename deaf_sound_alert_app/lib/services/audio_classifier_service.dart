import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
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
  AudioRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  String _sinhalaLocaleId = 'si_LK';
  Timer? _waveformTimer;
  bool _isListening = false;
  DateTime? _lastPeakDetectionTime;

  final List<double> _rollingBuf16k = List<double>.filled(16000, 0.0);
  int _rollingIdx = 0;
  int _totalSamplesPushed = 0;
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
    'sinhala_udaw_': 'උදව් (Udaw)',
    'sinhala_anathurak_': 'අනතුරක් (Anathurak)',
    'sinhala_beraganna_': 'බේරාගන්න (Beraganna)',
    'sinhala_ginnak_': 'ගින්නක් (Ginnak)',
    'sinhala_karadarayak_': 'කරදරයක් (Karadarayak)',
    'sinhala_balagena_': 'බලාගෙන (Balaagena)',
    'sinhala_ehata_wenna_': 'එහාට වෙන්න (Ehata Wenna)',
    'sinhala_parissamin_': 'පරිස්සමින් (Parissamin)',
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
      print('Native Neural Audio Classifier loaded successfully!');
    } catch (e) {
      print('Neural Classifier load exception: $e');
    }

    try {
      _speechAvailable = await _speech.initialize(
        onError: (val) {
          print('SpeechToText onError: $val');
          _restartSpeechListeningIfNeeded();
        },
        onStatus: (val) {
          print('SpeechToText onStatus: $val');
          if ((val == 'done' || val == 'notListening') && _isListening) {
            _restartSpeechListeningIfNeeded();
          }
        },
      );

      if (_speechAvailable) {
        final locales = await _speech.locales();
        for (var loc in locales) {
          if (loc.localeId.startsWith('si')) {
            _sinhalaLocaleId = loc.localeId;
            break;
          }
        }
      }
      print('SpeechToText initialized. Sinhala Locale: $_sinhalaLocaleId');
    } catch (e) {
      print('SpeechToText init exception: $e');
    }
  }

  void _safeListenSpeech() {
    if (!_speechAvailable || !_isListening) return;
    try {
      if (!_speech.isListening) {
        _speech.listen(
          onResult: (result) {
            if (!_isListening) return;
            String text = result.recognizedWords.toLowerCase().trim();
            if (text.isNotEmpty) {
              _transcriptController.add(result.recognizedWords);
              _processSpeechText(text);
            }
          },
          localeId: _sinhalaLocaleId,
          listenFor: const Duration(minutes: 30),
          pauseFor: const Duration(seconds: 10),
          partialResults: true,
          cancelOnError: false,
        );
      }
    } catch (e) {
      print('Speech listen error: $e');
    }
  }

  void _restartSpeechListeningIfNeeded() {
    if (!_isListening || !_speechAvailable) return;
    Timer(const Duration(milliseconds: 300), () {
      _safeListenSpeech();
    });
  }

  Future<bool> startListening() async {
    if (_isListening) return true;

    try {
      final status = await Permission.microphone.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        print('Microphone permission status denied');
      }
    } catch (_) {}

    _audioRecorder = AudioRecorder();
    _isListening = true;
    _rollingIdx = 0;
    _totalSamplesPushed = 0;

    // 1. Start continuous raw 16kHz PCM Audio Stream for 100% Offline AI Neural Classification
    try {
      final hasPerm = await _audioRecorder!.hasPermission();
      if (hasPerm) {
        final pcmStream = await _audioRecorder!.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );

        _audioStreamSubscription = pcmStream.listen((Uint8List chunk) {
          if (!_isListening) return;
          _handlePcmAudioChunk(chunk);
        }, onError: (err) {
          print('PCM Stream exception: $err');
        });
      }
    } catch (e) {
      print('Audio stream start exception: $e');
    }

    // 2. Parallel Speech Recognition Stream for Live Speech Transcript
    _safeListenSpeech();

    return true;
  }

  void _handlePcmAudioChunk(Uint8List chunk) {
    if (chunk.isEmpty) return;

    final ByteData byteData = ByteData.sublistView(chunk);
    final int sampleCount = chunk.length ~/ 2;
    double sumSquare = 0.0;

    for (int i = 0; i < sampleCount; i++) {
      int sample16 = byteData.getInt16(i * 2, Endian.little);
      double normSample = (sample16 / 32768.0).clamp(-1.0, 1.0);
      sumSquare += normSample * normSample;

      _rollingBuf16k[_rollingIdx] = normSample;
      _rollingIdx = (_rollingIdx + 1) % 16000;
      _totalSamplesPushed++;
    }

    final double rms = math.sqrt(sumSquare / (sampleCount > 0 ? sampleCount : 1));

    // Emit 40-band real-time visualizer waveform
    final math.Random rand = math.Random();
    final List<double> waveform = List.generate(40, (i) {
      double noise = (rand.nextDouble() - 0.5) * 0.15;
      return (rms * 4.0 + noise).clamp(0.08, 1.0);
    });
    _waveformController.add(waveform);

    // Run 100% Offline Deep Neural Network inference when RMS volume > ambient room threshold
    if (rms > 0.012 && _totalSamplesPushed >= 16000) {
      _runOfflineNeuralInference(rms);
    }
  }

  void _runOfflineNeuralInference(double rms) {
    final now = DateTime.now();
    if (_lastPeakDetectionTime != null &&
        now.difference(_lastPeakDetectionTime!).inMilliseconds < 750) {
      return;
    }

    // Reconstruct 1.0-second contiguous audio buffer
    final List<double> audioSlice = List<double>.filled(16000, 0.0);
    for (int i = 0; i < 16000; i++) {
      audioSlice[i] = _rollingBuf16k[(_rollingIdx + i) % 16000];
    }

    final prediction = _neuralClassifier.predict(audioSlice);
    if (prediction != null && prediction.probability >= 0.25) {
      String rawClass = prediction.label;
      String? mappedKey = _labelToSoundKey[rawClass];

      if (mappedKey != null && mappedKey != 'traffic') {
        _lastPeakDetectionTime = now;

        if (_displayNames.containsKey(mappedKey)) {
          _transcriptController.add(_displayNames[mappedKey]!);
        }

        simulateSoundDetection(mappedKey, confidence: prediction.probability);
      }
    }
  }

  void _processSpeechText(String text) {
    final Map<String, List<String>> keywordPatterns = {
      'sinhala_udaw_': ['udaw', 'udaww', 'udau', 'udawwa', 'udawwak', 'help', 'උදව්', 'උදව්වක්', 'උදවු'],
      'sinhala_anathurak_': ['anathurak', 'anatura', 'anathurai', 'danger', 'අනතුරක්', 'අනතුර', 'අනතුරයි'],
      'sinhala_beraganna_': ['beraganna', 'beeraganna', 'bcraganna', 'bera', 'beera', 'save', 'බේරාගන්න', 'බේරගන්න', 'බේරා', 'බේර'],
      'sinhala_ginnak_': ['ginnak', 'ginna', 'ginnaki', 'fire', 'ගින්නක්', 'ගින්න', 'ගිනි'],
      'sinhala_karadarayak_': ['karadarayak', 'karadara', 'karadarai', 'trouble', 'කරදරයක්', 'කරදර', 'කරදරයි'],
      'sinhala_balagena_': ['balagena', 'balagenna', 'balaagena', 'balaganna', 'balang', 'watch', 'lookout', 'බලාගෙන', 'බලන්', 'බලාගෙනම'],
      'sinhala_ehata_wenna_': ['ehata', 'wenna', 'ehatawenna', 'move', 'එහාට', 'වෙන්න', 'එහාටවෙන්න'],
      'sinhala_parissamin_': ['parissamin', 'parisamin', 'parissamen', 'parisamen', 'parissam', 'parisam', 'careful', 'පරිස්සමින්', 'පරිස්සමෙන්', 'පරිසමින්', 'පරිස්සම්'],
      'baby crying': ['baby', 'cry', 'crying', 'ළදරු'],
      'vehicle horns': ['horn', 'horns', 'vehicle', 'වාහන'],
      'ambulance': ['ambulance', 'siren', 'ගිලන්'],
      'dog_bark_dataset': ['dog', 'bark', 'barking', 'බල්ලා'],
      'traffic': ['traffic', 'තදබදය'],
      'road': ['road', 'පාරේ'],
    };

    final now = DateTime.now();

    keywordPatterns.forEach((key, patterns) {
      bool matches = patterns.any((pattern) => text.contains(pattern));
      if (matches) {
        final lastTime = _lastKeywordTriggerTimes[key];
        if (lastTime == null || now.difference(lastTime).inMilliseconds > 1200) {
          _lastKeywordTriggerTimes[key] = now;
          if (_displayNames.containsKey(key)) {
            _transcriptController.add(_displayNames[key]!);
          }
          simulateSoundDetection(key, confidence: 0.98);
        }
      }
    });
  }

  void stopListening() {
    _isListening = false;
    if (_speech.isListening) {
      _speech.stop();
    }
    _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    _waveformTimer?.cancel();
    _waveformTimer = null;
    try {
      _audioRecorder?.dispose();
    } catch (_) {}
    _audioRecorder = null;
  }

  Future<void> simulateSoundDetection(String soundKey, {double confidence = 0.92}) async {
    final soundConfig = SoundConfigService().getConfig(soundKey);
    if (soundConfig == null || !soundConfig.isEnabled) return;

    final event = DetectedSound(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      soundKey: soundConfig.key,
      soundName: soundConfig.name,
      category: soundConfig.category,
      priority: soundConfig.priority,
      confidence: confidence,
      timestamp: DateTime.now(),
    );

    // Save log
    await HistoryService().addEvent(event);

    // Trigger Phone Vibration
    await VibrationService().triggerVibration(event.priority);

    // Send Alert Push Notification to Android Phone & Smartwatch Yesido IO 39
    await SmartwatchService().sendAlertToWatch(event);

    // Emit event to UI
    _controller.add(event);
  }

  void dispose() {
    stopListening();
    _controller.close();
    _waveformController.close();
    _transcriptController.close();
  }
}
