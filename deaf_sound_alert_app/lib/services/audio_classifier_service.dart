import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:record/record.dart';
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

  Timer? _sttWatchdogTimer;
  bool _speechAvailable = false;
  String? _selectedLocaleId;
  bool _isListening = false;
  double _latestSoundVolume = 0.02;
  final List<double> _visualizerBars = List<double>.filled(40, 0.15);

  bool _isSamplingAcousticPCM = false;
  int _highVolumeStartTimeMs = 0;
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
            _highVolumeStartTimeMs = 0;
            final String formattedDisplay = _formatTranscriptWithSinhala(rawWords);
            _transcriptController.add(formattedDisplay);
            _processSpeechText(rawWords.toLowerCase());
          }
        },
        onSoundLevelChange: (level) {
          if (!_isListening) return;
          double soundVol = (0.25 + (level.clamp(-2.0, 10.0) / 10.0)).clamp(0.18, 1.0);
          _updateWaveformVolume(soundVol);
          _checkAcousticAudioSampleNeeded(soundVol);
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
    _lastSpeechTimeMs = nowMs;
    _latestSoundVolume = 0.25;

    // Start 50 FPS smooth visualizer animation ticker
    _startVisualizerTicker();

    // 1. Continuous Live Speech Engine for transcribing EVERY single word spoken & sound alerts
    _safeListenSpeech();

    return true;
  }

  void _checkAcousticAudioSampleNeeded(double soundVol) {
    if (!_isListening || _isSamplingAcousticPCM) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Do NOT sample if speech was detected within the last 2.0 seconds!
    // This gives SpeechRecognizer 100% full, uninterrupted mic access for instant Live Speech display
    // and prevents human speech from being sampled into the environmental sound classifier!
    if (nowMs - _lastSpeechTimeMs < 2000) {
      _highVolumeStartTimeMs = 0;
      return;
    }

    // High acoustic sound level detected (> 0.35)
    // Non-speech sound sustained for 350ms
    if (soundVol >= 0.35) {
      if (_highVolumeStartTimeMs == 0) {
        _highVolumeStartTimeMs = nowMs;
      } else if (nowMs - _highVolumeStartTimeMs >= 350) {
        _triggerAcousticNeuralSample();
      }
    } else {
      _highVolumeStartTimeMs = 0;
    }
  }

  Future<void> _triggerAcousticNeuralSample() async {
    if (_isSamplingAcousticPCM || !_isListening) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastSpeechTimeMs < 2000) return;

    _isSamplingAcousticPCM = true;
    _highVolumeStartTimeMs = 0;

    try {
      final AudioRecorder sampleRecorder = AudioRecorder();
      if (await sampleRecorder.hasPermission()) {
        final stream = await sampleRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            numChannels: 1,
            sampleRate: 16000,
          ),
        );

        final List<double> sampledPcm = [];
        final Completer<void> sampleCompleter = Completer<void>();

        StreamSubscription? sub;
        sub = stream.listen((bytes) {
          final samples = List<double>.generate(bytes.length ~/ 2, (i) {
            int byte0 = bytes[i * 2];
            int byte1 = bytes[i * 2 + 1];
            int val = (byte1 << 8) | byte0;
            if (val >= 32768) val -= 65536;
            return val / 32768.0;
          });
          sampledPcm.addAll(samples);
          if (sampledPcm.length >= 6400) {
            if (!sampleCompleter.isCompleted) sampleCompleter.complete();
          }
        }, onError: (_) {
          if (!sampleCompleter.isCompleted) sampleCompleter.complete();
        });

        await sampleCompleter.future.timeout(
          const Duration(milliseconds: 400),
          onTimeout: () {},
        );

        await sub.cancel();
        try {
          await sampleRecorder.stop();
          await sampleRecorder.dispose();
        } catch (_) {}

        // Double check: if speech was detected during the sample, DISCARD IMMEDIATELY!
        final postSampleMs = DateTime.now().millisecondsSinceEpoch;
        if (postSampleMs - _lastSpeechTimeMs < 2000) {
          return;
        }

        if (sampledPcm.isNotEmpty) {
          final window1s = List<double>.filled(16000, 0.0);
          for (int i = 0; i < math.min(16000, sampledPcm.length); i++) {
            window1s[i] = sampledPcm[i];
          }

          final pred = _neuralClassifier.predict(window1s);
          if (pred != null) {
            final topLabel = pred.label;
            final topProb = pred.probability;
            final mappedKey = _labelToSoundKey[topLabel] ?? topLabel;

            // Total probability across all Sinhala speech classes in neural model
            double speechProb = 0.0;
            const speechClasses = ['udaw', 'beeraganna', 'ginnak', 'anathurak', 'karadarayak', 'balagena', 'parissamin', 'ehata_wenna'];
            for (var sc in speechClasses) {
              speechProb += (pred.allProbabilities[sc] ?? 0.0);
            }

            // If the acoustic sample contains ANY speech or a Sinhala word, NEVER trigger an environmental sound card!
            if (speechProb >= 0.08 || mappedKey.startsWith('sinhala_')) {
              _lastSpeechTimeMs = DateTime.now().millisecondsSinceEpoch;
              return;
            }

            final double dogProb = pred.allProbabilities['dog_barking'] ?? 0.0;
            final double babyProb = pred.allProbabilities['baby_crying'] ?? 0.0;

            // ONLY trigger environmental sound when played/heard, with strict speech protection:
            if (mappedKey == 'dog_bark_dataset' || topLabel == 'dog_barking' || dogProb >= 0.72) {
              if (math.max(dogProb, topProb) >= 0.72) {
                final String displayName = _displayNames['dog_bark_dataset'] ?? 'Dog Barking';
                _transcriptController.add(displayName);
                simulateSoundDetection('dog_bark_dataset', confidence: math.max(dogProb, topProb), overrideCooldown: true);
                return;
              }
            } else if (mappedKey == 'baby crying' || topLabel == 'baby_crying' || babyProb >= 0.90) {
              // High 0.90 threshold ensures human speech vowels (e.g. "කරන්න") NEVER falsely trigger baby crying!
              if (math.max(babyProb, topProb) >= 0.90 && speechProb < 0.04) {
                final String displayName = _displayNames['baby crying'] ?? 'Baby Crying';
                _transcriptController.add(displayName);
                simulateSoundDetection('baby crying', confidence: math.max(babyProb, topProb), overrideCooldown: true);
                return;
              }
            } else if (mappedKey == 'ambulance' || topLabel == 'ambulance_siren') {
              if (topProb >= 0.70) {
                final String displayName = _displayNames['ambulance'] ?? 'Ambulance Siren';
                _transcriptController.add(displayName);
                simulateSoundDetection('ambulance', confidence: topProb, overrideCooldown: true);
                return;
              }
            } else if (mappedKey == 'fire_truck' || topLabel == 'fire_truck' || topLabel == 'fire_alarm' || topLabel == 'fire_engine' || topLabel == 'fire_siren') {
              if (topProb >= 0.68) {
                final String displayName = _displayNames['fire_truck'] ?? 'Fire Alarm / Siren';
                _transcriptController.add(displayName);
                simulateSoundDetection('fire_truck', confidence: topProb, overrideCooldown: true);
                return;
              }
            } else if (mappedKey == 'vehicle horns' || topLabel == 'vehicle_horn') {
              if (topProb >= 0.70) {
                final String displayName = _displayNames['vehicle horns'] ?? 'Vehicle Horns';
                _transcriptController.add(displayName);
                simulateSoundDetection('vehicle horns', confidence: topProb, overrideCooldown: true);
                return;
              }
            } else if (mappedKey == 'traffic' || topLabel == 'background_traffic') {
              if (topProb >= 0.70) {
                final String displayName = _displayNames['traffic'] ?? 'Traffic Noise';
                _transcriptController.add(displayName);
                simulateSoundDetection('traffic', confidence: topProb, overrideCooldown: true);
                return;
              }
            }
          }
        }
      }
    } catch (e) {
      // Ignore
    } finally {
      _isSamplingAcousticPCM = false;
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
    _visualizerTicker?.cancel();
    _visualizerTicker = null;
    _latestSoundVolume = 0.02;
    _waveformController.add([]);

    if (_speech.isListening) {
      _speech.stop();
    }
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
