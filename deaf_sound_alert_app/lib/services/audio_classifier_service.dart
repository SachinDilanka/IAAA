import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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

  static const MethodChannel _bgChannel = MethodChannel('com.deafalert.app/background_service');
  final NativeNeuralAudioClassifier _neuralClassifier = NativeNeuralAudioClassifier();
  final stt.SpeechToText _speech = stt.SpeechToText();

  Timer? _sttWatchdogTimer;
  bool _speechAvailable = false;
  String? _selectedLocaleId;
  bool _isListening = false;
  double _latestSoundVolume = 0.02;
  final List<double> _visualizerBars = List<double>.filled(40, 0.15);

  int _lastSpeechTimeMs = 0;
  DateTime? _lastGlobalAlertTime;

  final Map<String, DateTime> _lastKeywordTriggerTimes = {};

  final _controller = StreamController<DetectedSound>.broadcast();
  final _waveformController = StreamController<List<double>>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();

  bool get isListening => _isListening;
  Stream<DetectedSound> get onSoundDetected => _controller.stream;
  Stream<List<double>> get onWaveformUpdated => _waveformController.stream;
  Stream<String> get onTranscriptUpdated => _transcriptController.stream;

  final Map<String, String> _labelToSoundKey = {
    'siren': 'siren',
    'siren_sound': 'siren',
    'ambulance_siren': 'ambulance',
    'ambulance': 'ambulance',
    'vehicle_horn': 'vehicle horns',
    'vehicle horns': 'vehicle horns',
    'baby_crying': 'baby crying',
    'baby crying': 'baby crying',
    'fire_truck': 'fire_truck',
    'fire_truck_dataset': 'fire_truck',
    'fire_engine': 'fire_truck',
    'fire_siren': 'fire_truck',
    'fire_alarm': 'fire_truck',
    'fire': 'fire_truck',
    'smoke_alarm': 'fire_truck',
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
    'sinhala_udaw_': 'Udaw (උදව්)',
    'sinhala_anathurak_': 'Anathurak (අනතුරක්)',
    'sinhala_beraganna_': 'Beraganna (බේරාගන්න)',
    'sinhala_ginnak_': 'Ginnak (ගින්නක්)',
    'sinhala_karadarayak_': 'Karadarayak (කරදරයක්)',
    'sinhala_balagena_': 'Balagena (බලාගෙන)',
    'sinhala_ehata_wenna_': 'Ehata Wenna (එහාට වෙන්න)',
    'sinhala_parissamin_': 'Parissamin (පරිස්සමින්)',
    'siren': 'Siren Sound (සයිරන්)',
    'ambulance': 'Ambulance Siren (ගිලන් රථ)',
    'fire_truck': 'Fire Alarm / Siren (ගිනි නිවන)',
    'baby crying': 'Baby Crying (ළදරු හැඬීම)',
    'vehicle horns': 'Vehicle Horns (වාහන නලා)',
    'dog_bark_dataset': 'Dog Barking (බල්ලා බුරන)',
    'traffic': 'Traffic Noise (වාහන තදබදය)',
    'road': 'Road Sounds (පාරේ ශබ්දය)',
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
          _checkAcousticAudioSampleNeeded(soundVol);
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

  bool _isSamplingAcousticPCM = false;
  int _highVolumeStartTimeMs = 0;

  void _checkAcousticAudioSampleNeeded(double soundVol) {
    if (!_isListening || _isSamplingAcousticPCM) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // High acoustic sound level detected (> 0.35)
    // Only sample environmental sounds if no speech was detected in the last 3.0 seconds!
    if (soundVol >= 0.35) {
      if (_highVolumeStartTimeMs == 0) {
        _highVolumeStartTimeMs = nowMs;
      } else if (nowMs - _highVolumeStartTimeMs >= 400 && nowMs - _lastSpeechTimeMs >= 3000) {
        _triggerAcousticNeuralSample();
      }
    } else {
      _highVolumeStartTimeMs = 0;
    }
  }

  Future<void> _triggerAcousticNeuralSample() async {
    if (_isSamplingAcousticPCM || !_isListening) return;
    _isSamplingAcousticPCM = true;
    _highVolumeStartTimeMs = 0;

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }

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
        Completer<void> sampleCompleter = Completer<void>();

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
          if (sampledPcm.length >= 16000) {
            if (!sampleCompleter.isCompleted) sampleCompleter.complete();
          }
        }, onError: (_) {
          if (!sampleCompleter.isCompleted) sampleCompleter.complete();
        });

        await sampleCompleter.future.timeout(
          const Duration(milliseconds: 900),
          onTimeout: () {},
        );

        await sub.cancel();
        try {
          await sampleRecorder.stop();
        } catch (_) {}

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

            final double dogProb = pred.allProbabilities['dog_barking'] ?? 0.0;
            final double babyProb = pred.allProbabilities['baby_crying'] ?? 0.0;

            if (dogProb >= 0.28) {
              simulateSoundDetection('dog_bark_dataset', confidence: dogProb, overrideCooldown: true);
              return;
            }

            if (babyProb >= 0.28) {
              simulateSoundDetection('baby crying', confidence: babyProb, overrideCooldown: true);
              return;
            }

            // Siren Sound / Ambulance Siren
            if (mappedKey == 'siren' || mappedKey == 'ambulance' || topLabel == 'ambulance_siren') {
              if (topProb >= 0.35) {
                final targetKey = SoundConfigService().getConfig('siren')?.isEnabled == true ? 'siren' : 'ambulance';
                simulateSoundDetection(targetKey, confidence: topProb, overrideCooldown: true);
                return;
              }
            }

            // Fire Truck Siren / Fire Alarm
            if (mappedKey == 'fire_truck' || topLabel == 'fire_truck' || topLabel == 'fire_alarm') {
              if (topProb >= 0.35) {
                simulateSoundDetection('fire_truck', confidence: topProb, overrideCooldown: true);
                return;
              }
            }

            if (!mappedKey.startsWith('sinhala_') && mappedKey != 'road' && mappedKey != 'traffic') {
              if (topProb >= 0.35) {
                simulateSoundDetection(mappedKey, confidence: topProb, overrideCooldown: true);
              }
            }
          }
        }
      }
    } catch (e) {
      print('Acoustic neural sampling error: $e');
    } finally {
      _isSamplingAcousticPCM = false;
      if (_isListening && !_speech.isListening && !_isRestartingStt) {
        _safeListenSpeech();
      }
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
      await [
        Permission.microphone,
        Permission.notification,
      ].request();
    } catch (_) {}

    try {
      await _bgChannel.invokeMethod('startService');
    } catch (e) {
      print('Background audio service start error: $e');
    }

    _isListening = true;
    _isRestartingStt = false;
    _lastSpeechTimeMs = DateTime.now().millisecondsSinceEpoch;
    _latestSoundVolume = 0.25;

    // Start 50 FPS smooth visualizer animation ticker
    _startVisualizerTicker();

    // 1. Continuous Live Speech Engine for transcribing EVERY single word spoken & sound alerts
    _safeListenSpeech();

    return true;
  }

  String _formatTranscriptWithSinhala(String rawWords) {
    final String lower = rawWords.toLowerCase();

    final Map<String, String> wordToSinhala = {
      'udaw': 'Udaw (උදව්)',
      'udau': 'Udaw (උදව්)',
      'udaww': 'Udaw (උදව්)',
      'uda': 'Udaw (උදව්)',
      'udaa': 'Udaw (උදව්)',
      'udav': 'Udaw (උදව්)',
      'help': 'Udaw (උදව්)',
      'sos': 'Udaw (උදව්)',
      'emergency': 'Udaw (උදව්)',
      'උදව්': 'Udaw (උදව්)',
      'උදවු': 'Udaw (උදව්)',
      'ehata wenna': 'Ehata Wenna (එහාට වෙන්න)',
      'eheta wenna': 'Ehata Wenna (එහාට වෙන්න)',
      'ehatawenna': 'Ehata Wenna (එහාට වෙන්න)',
      'ehetawenna': 'Ehata Wenna (එහාට වෙන්න)',
      'ehata': 'Ehata Wenna (එහාට වෙන්න)',
      'eheta': 'Ehata Wenna (එහාට වෙන්න)',
      'move aside': 'Ehata Wenna (එහාට වෙන්න)',
      'එහාට වෙන්න': 'Ehata Wenna (එහාට වෙන්න)',
      'එහාට': 'Ehata Wenna (එහාට වෙන්න)',
      'anathurak': 'Anathurak (අනතුරක්)',
      'anatura': 'Anathurak (අනතුරක්)',
      'anathura': 'Anathurak (අනතුරක්)',
      'danger': 'Anathurak (අනතුරක්)',
      'accident': 'Anathurak (අනතුරක්)',
      'warning': 'Anathurak (අනතුරක්)',
      'අනතුරක්': 'Anathurak (අනතුරක්)',
      'beraganna': 'Beraganna (බේරාගන්න)',
      'beeraganna': 'Beraganna (බේරාගන්න)',
      'save': 'Beraganna (බේරාගන්න)',
      'rescue': 'Beraganna (බේරාගන්න)',
      'බේරගන්න': 'Beraganna (බේරාගන්න)',
      'බේරාගන්න': 'Beraganna (බේරාගන්න)',
      'ginnak': 'Ginnak (ගින්නක්)',
      'ginna': 'Ginnak (ගින්නක්)',
      'fire': 'Ginnak (ගින්නක්)',
      'fire alarm': 'Ginnak (ගින්නක්)',
      'burning': 'Ginnak (ගින්නක්)',
      'ගින්නක්': 'Ginnak (ගින්නක්)',
      'karadarayak': 'Karadarayak (කරදරයක්)',
      'karadara': 'Karadarayak (කරදරයක්)',
      'trouble': 'Karadarayak (කරදරයක්)',
      'problem': 'Karadarayak (කරදරයක්)',
      'කරදරයක්': 'Karadarayak (කරදරයක්)',
      'balagena': 'Balagena (බලාගෙන)',
      'balaagena': 'Balagena (බලාගෙන)',
      'watch out': 'Balagena (බලාගෙන)',
      'look out': 'Balagena (බලාගෙන)',
      'බලාගෙන': 'Balagena (බලාගෙන)',
      'parissamin': 'Parissamin (පරිස්සමින්)',
      'parisamin': 'Parissamin (පරිස්සමින්)',
      'parissamen': 'Parissamin (පරිස්සමින්)',
      'prissin': 'Parissamin (පරිස්සමින්)',
      'parissin': 'Parissamin (පරිස්සමින්)',
      'prissamin': 'Parissamin (පරිස්සමින්)',
      'careful': 'Parissamin (පරිස්සමින්)',
      'take care': 'Parissamin (පරිස්සමින්)',
      'පරිස්සමින්': 'Parissamin (පරිස්සමින්)',
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
        'udaw', 'udaww', 'udau', 'uda', 'udaa', 'udawwa', 'udawwak', 'udauwa', 'udav', 'udavv', 'help', 'udawu', 'udauw', 'sos', 'emergency',
        'උදව්', 'උදව්වක්', 'උදවු', 'උදවු කරන්න', 'උදව් කරන්න', 'උදව්ව', 'උදව්ක්', 'උදව'
      ],
      'sinhala_anathurak_': [
        'anathurak', 'anatura', 'anathura', 'anathurai', 'anaturak', 'danger', 'anaturai', 'anathurac', 'accident', 'warning', 'anatur', 'anathur',
        'අනතුරක්', 'අනතුර', 'අනතුරයි'
      ],
      'sinhala_beraganna_': [
        'beraganna', 'beeraganna', 'bcraganna', 'beera', 'beragan', 'save me', 'rescue', 'beragannako', 'berannako', 'bera ganna',
        'බේරාගන්න', 'බේරගන්න', 'බේරාගන්නකෝ', 'බේරගන්නකෝ', 'බේරන්න'
      ],
      'sinhala_ginnak_': [
        'ginnak', 'ginna', 'ginnaki', 'ginnac', 'fire', 'fire alarm', 'ginak', 'firefire', 'burning',
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
        'ehata wenna', 'eheta wenna', 'ehatawenna', 'ehetawenna', 'ehata', 'move aside', 'move away', 'step back', 'get away',
        'එහාට වෙන්න', 'එහාටවෙන්න', 'එහාට'
      ],
      'sinhala_parissamin_': [
        'parissamin', 'parisamin', 'parissamen', 'parisamen', 'parissam', 'parisam', 'be careful', 'take care',
        'පරිස්සමින්', 'පරිස්සමෙන්', 'පරිසමින්', 'පරිස්සම්'
      ],
      'siren': [
        'siren', 'sirens', 'සයිරන්'
      ],
      'ambulance': [
        'wee-ow', 'weeow', 'wee ow', 'nee-naw', 'neenaw', 'nee naw', 'ambulance', 'ambulance siren', 'wee oo', 'weeoo', 'wail', 'wailing',
        'ගිලන්', 'වී ඕ', 'වීඕ', 'නි නෝ', 'නිනෝ', 'ගිලන් රථ'
      ],
      'dog_bark_dataset': [
        'woof-woof', 'woofwoof', 'woof woof', 'arf-arf', 'arfarf', 'arf arf', 'ruff-ruff', 'ruffruff', 'ruff ruff', 'woof', 'woofs', 'arf', 'ruff', 'bark', 'barks', 'barking', 'dog', 'dogs', 'dog barking', 'dog bark', 'yap', 'yapping', 'bow bow', 'bau bau',
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
    _latestSoundVolume = 0.02;
    _waveformController.add([]);

    try {
      _bgChannel.invokeMethod('stopService');
    } catch (_) {}

    if (_speech.isListening) {
      _speech.stop();
    }
  }

  DateTime? _lastEmittedAlertTime;
  final Map<String, DateTime> _lastSoundAlertTimes = {};

  Future<void> simulateSoundDetection(String soundKey, {double confidence = 0.92, bool overrideCooldown = false}) async {
    final now = DateTime.now();

    if (!overrideCooldown) {
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

    // 3. Trigger Flashlight Flashing pattern instantly (synced with vibration)
    FlashlightService().triggerFlashlightPattern(event.priority);

    // 4. Wake up screen if locked or off in pocket
    try {
      _bgChannel.invokeMethod('wakeScreen');
    } catch (_) {}

    // 5. Save log to history & sync to Yesido IO 39 smartwatch asynchronously in background
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
