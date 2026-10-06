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
  String? _pendingSpeechClass;
  int _pendingSpeechVotes = 0;
  int _pendingSpeechAtMs = 0;
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

  static const Map<String, String> _sinhalaLiveSpeechWord = {
    'sinhala_udaw_': 'udaw',
    'sinhala_beraganna_': 'beeraganna',
    'sinhala_ginnak_': 'ginnak',
    'sinhala_anathurak_': 'anathurak',
    'sinhala_karadarayak_': 'karadarayak',
    'sinhala_balagena_': 'balagena',
    'sinhala_ehata_wenna_': 'ehata wenna',
    'sinhala_parissamin_': 'parissamin',
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

  // Exact Live Speech display strings for 6 Environmental sounds
  static final Map<String, String> _envLiveSpeechDisplay = {
    'ambulance': 'ගිලන් රථ සයිරන් (Ambulance Siren)',
    'fire_truck': 'ගිනි නිවන රථ ශබ්දය (Fire Truck Siren)',
    'vehicle horns': 'වාහන හොන් (Vehicle Horns)',
    'baby crying': 'ළදරු හැඬීම (Baby Crying)',
    'dog_bark_dataset': 'බල්ලා බුරන ශබ්දය (Dog Barking)',
    'traffic': 'වාහන තදබදය (Traffic Noise)',
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
    _rollingIdx = 0;
    _total16kPushed = 0;
    _lastMlTimeMs = 0;
    _pendingSpeechClass = null;
    _pendingSpeechVotes = 0;
    _pendingSpeechAtMs = 0;
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

  Future<void> _startSpeechRecognition() async {
    try {
      await _speechSubscription?.cancel();
      _speechSubscription = _speechEvents.receiveBroadcastStream().listen(
        (event) {
          if (!_isListening || event is! Map) return;
          final type = event['type']?.toString();

          if (type == 'rms') {
            final rmsVal = (event['rms'] as num?)?.toDouble() ?? 0.0;
            if (rmsVal > 0.0) {
              final normVol = ((rmsVal + 2.0) / 12.0).clamp(0.18, 1.0);
              _updateWaveformVolume(normVol);
            }
            return;
          }

          final text = event['text']?.toString().trim() ?? '';
          final rawCandidates = (event['candidates'] as List<dynamic>?)
                  ?.map((c) => c.toString())
                  .toList() ??
              [];

          if ((type == 'partialResult' || type == 'finalResult') &&
              text.isNotEmpty) {
            _lastSpeechTimeMs = DateTime.now().millisecondsSinceEpoch;
            _setSttStatus('Listening for Sinhala emergency keywords');
            _processSpeechText(text, candidates: rawCandidates);
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
          'Speech recognition active. Say udaw, beeraganna, ginnak, anathurak, karadarayak, balagena, ehata wenna, or parissamin.');
    } catch (error) {
      _setSttStatus('Could not start speech recognition: $error');
    }
  }

  String _normalizeText(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s\u0D80-\u0DFF]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void _processSpeechText(String rawText, {List<String> candidates = const []}) {
    final cleanMain = _normalizeText(rawText);
    if (cleanMain.isEmpty) return;

    final targets = [cleanMain, ...candidates.map(_normalizeText)]
        .where((s) => s.isNotEmpty)
        .toList();

    const sinhalaKeywords = <String, String>{
      // 1. Udaw (Help) -> udaw  →  උදව් (Udaw - Help)
      'udaw': 'sinhala_udaw_',
      'udau': 'sinhala_udaw_',
      'udav': 'sinhala_udaw_',
      'udaaw': 'sinhala_udaw_',
      'udaav': 'sinhala_udaw_',
      'uda': 'sinhala_udaw_',
      'help': 'sinhala_udaw_',
      'wood owl': 'sinhala_udaw_',
      'woodowl': 'sinhala_udaw_',
      'you down': 'sinhala_udaw_',
      'you dow': 'sinhala_udaw_',
      'you do': 'sinhala_udaw_',
      'u down': 'sinhala_udaw_',
      'u dow': 'sinhala_udaw_',
      'you doubted': 'sinhala_udaw_',
      'who down': 'sinhala_udaw_',
      'who doubt': 'sinhala_udaw_',
      'who do': 'sinhala_udaw_',
      'you dive': 'sinhala_udaw_',
      'you dial': 'sinhala_udaw_',
      'you dough': 'sinhala_udaw_',
      'you know': 'sinhala_udaw_',
      'you have': 'sinhala_udaw_',
      'you doll': 'sinhala_udaw_',
      'you dumb': 'sinhala_udaw_',
      'you d': 'sinhala_udaw_',
      'you dao': 'sinhala_udaw_',
      'out down': 'sinhala_udaw_',
      'how do': 'sinhala_udaw_',
      'hudaw': 'sinhala_udaw_',
      'hudau': 'sinhala_udaw_',
      'ooh dow': 'sinhala_udaw_',
      'oo dow': 'sinhala_udaw_',
      'udo': 'sinhala_udaw_',
      'down': 'sinhala_udaw_',
      'dow': 'sinhala_udaw_',
      'dao': 'sinhala_udaw_',
      'you d have': 'sinhala_udaw_',
      'you d how': 'sinhala_udaw_',
      'උදව්': 'sinhala_udaw_',
      'උදවු': 'sinhala_udaw_',
      'උදව්ව': 'sinhala_udaw_',
      'උදව් කරන්න': 'sinhala_udaw_',

      // 2. Beeraganna (Save Me) -> beeraganna  →  බේරගන්න (Beraganna - Save Me)
      'beeraganna': 'sinhala_beraganna_',
      'beraganna': 'sinhala_beraganna_',
      'beera ganna': 'sinhala_beraganna_',
      'bera ganna': 'sinhala_beraganna_',
      'rescue': 'sinhala_beraganna_',
      'save me': 'sinhala_beraganna_',
      'bear gonna': 'sinhala_beraganna_',
      'beer gonna': 'sinhala_beraganna_',
      'bear gunner': 'sinhala_beraganna_',
      'beer gunner': 'sinhala_beraganna_',
      'bear gone': 'sinhala_beraganna_',
      'beer gone': 'sinhala_beraganna_',
      'bear got': 'sinhala_beraganna_',
      'beer got': 'sinhala_beraganna_',
      'bear kinda': 'sinhala_beraganna_',
      'beer kinda': 'sinhala_beraganna_',
      'we are gonna': 'sinhala_beraganna_',
      'big enough': 'sinhala_beraganna_',
      'better gonna': 'sinhala_beraganna_',
      'be a gunner': 'sinhala_beraganna_',
      'beer can': 'sinhala_beraganna_',
      'beer gun': 'sinhala_beraganna_',
      'baragana': 'sinhala_beraganna_',
      'baraganna': 'sinhala_beraganna_',
      'biraganna': 'sinhala_beraganna_',
      'biragana': 'sinhala_beraganna_',
      'bear gotta': 'sinhala_beraganna_',
      'bare gonna': 'sinhala_beraganna_',
      'be gonna': 'sinhala_beraganna_',
      'beer garden': 'sinhala_beraganna_',
      'බේරගන්න': 'sinhala_beraganna_',
      'බේරාගන්න': 'sinhala_beraganna_',
      'බේර ගන්න': 'sinhala_beraganna_',
      'බේරා ගන්න': 'sinhala_beraganna_',

      // 3. Ginnak (Fire) -> ginnak  →  ගින්නක් (Ginnak - Fire)
      'ginnak': 'sinhala_ginnak_',
      'ginna': 'sinhala_ginnak_',
      'fire': 'sinhala_ginnak_',
      'gin knock': 'sinhala_ginnak_',
      'gin noc': 'sinhala_ginnak_',
      'gin nac': 'sinhala_ginnak_',
      'good night': 'sinhala_ginnak_',
      'get knock': 'sinhala_ginnak_',
      'gin not': 'sinhala_ginnak_',
      'in knock': 'sinhala_ginnak_',
      'give knock': 'sinhala_ginnak_',
      'gin nook': 'sinhala_ginnak_',
      'green neck': 'sinhala_ginnak_',
      'gin act': 'sinhala_ginnak_',
      'gin nut': 'sinhala_ginnak_',
      'gin neck': 'sinhala_ginnak_',
      'kin knock': 'sinhala_ginnak_',
      'can knock': 'sinhala_ginnak_',
      'gin duck': 'sinhala_ginnak_',
      'gin back': 'sinhala_ginnak_',
      'ginnac': 'sinhala_ginnak_',
      'gina': 'sinhala_ginnak_',
      'gink': 'sinhala_ginnak_',
      'ගින්නක්': 'sinhala_ginnak_',
      'ගින්න': 'sinhala_ginnak_',
      'ගිනි': 'sinhala_ginnak_',
      'ගින්දර': 'sinhala_ginnak_',

      // 4. Anathurak (Danger) -> anathurak  →  අනතුරක් (Anathurak - Danger)
      'anathurak': 'sinhala_anathurak_',
      'anaturak': 'sinhala_anathurak_',
      'anathura': 'sinhala_anathurak_',
      'anatura': 'sinhala_anathurak_',
      'danger': 'sinhala_anathurak_',
      'another act': 'sinhala_anathurak_',
      'another rock': 'sinhala_anathurak_',
      'another rack': 'sinhala_anathurak_',
      'another ache': 'sinhala_anathurak_',
      'another track': 'sinhala_anathurak_',
      'another arc': 'sinhala_anathurak_',
      'another accurate': 'sinhala_anathurak_',
      'අනතුරක්': 'sinhala_anathurak_',
      'අනතුර': 'sinhala_anathurak_',
      'අනතුරු': 'sinhala_anathurak_',

      // 5. Karadarayak (Trouble) -> karadarayak  →  කරදරයක් (Karadarayak - Trouble)
      'karadarayak': 'sinhala_karadarayak_',
      'karadara': 'sinhala_karadarayak_',
      'kara darayak': 'sinhala_karadarayak_',
      'karadara yak': 'sinhala_karadarayak_',
      'karadhara': 'sinhala_karadarayak_',
      'trouble': 'sinhala_karadarayak_',
      'cardiac': 'sinhala_karadarayak_',
      'color dark': 'sinhala_karadarayak_',
      'car the rock': 'sinhala_karadarayak_',
      'car that i act': 'sinhala_karadarayak_',
      'car that i': 'sinhala_karadarayak_',
      'car direct': 'sinhala_karadarayak_',
      'canada act': 'sinhala_karadarayak_',
      'care direct': 'sinhala_karadarayak_',
      'car the rack': 'sinhala_karadarayak_',
      'car dark': 'sinhala_karadarayak_',
      'color direct': 'sinhala_karadarayak_',
      'color doctor': 'sinhala_karadarayak_',
      'car the right': 'sinhala_karadarayak_',
      'car door act': 'sinhala_karadarayak_',
      'car the react': 'sinhala_karadarayak_',
      'current direct': 'sinhala_karadarayak_',
      'character': 'sinhala_karadarayak_',
      'කරදරයක්': 'sinhala_karadarayak_',
      'කරදර': 'sinhala_karadarayak_',
      'කරදරේ': 'sinhala_karadarayak_',

      // 6. Balagena (Watch Out) -> balagena  →  බලාගෙන (Balaagena - Watch Out)
      'balagena': 'sinhala_balagena_',
      'balaagena': 'sinhala_balagena_',
      'watch out': 'sinhala_balagena_',
      'bala gonna': 'sinhala_balagena_',
      'ballerina': 'sinhala_balagena_',
      'baller gonna': 'sinhala_balagena_',
      'body gonna': 'sinhala_balagena_',
      'by la gonna': 'sinhala_balagena_',
      'balaganna': 'sinhala_balagena_',
      'balagan': 'sinhala_balagena_',
      'bottle gonna': 'sinhala_balagena_',
      'bala gone': 'sinhala_balagena_',
      'balagene': 'sinhala_balagena_',
      'palagena': 'sinhala_balagena_',
      'pala gonna': 'sinhala_balagena_',
      'bell again': 'sinhala_balagena_',
      'ball again': 'sinhala_balagena_',
      'bella gonna': 'sinhala_balagena_',
      'balagener': 'sinhala_balagena_',
      'bala gunner': 'sinhala_balagena_',
      'bala game': 'sinhala_balagena_',
      'balance': 'sinhala_balagena_',
      'බලාගෙන': 'sinhala_balagena_',
      'බලන්න': 'sinhala_balagena_',
      'බලගෙන': 'sinhala_balagena_',

      // 7. Ehata Wenna (Move Aside) -> ehata wenna  →  එහාට වෙන්න (Ehata Wenna - Move Aside)
      'ehata wenna': 'sinhala_ehata_wenna_',
      'ehatawenna': 'sinhala_ehata_wenna_',
      'ehata': 'sinhala_ehata_wenna_',
      'ehatha wenna': 'sinhala_ehata_wenna_',
      'ehata win': 'sinhala_ehata_wenna_',
      'move aside': 'sinhala_ehata_wenna_',
      'aside': 'sinhala_ehata_wenna_',
      'a hat to win': 'sinhala_ehata_wenna_',
      'a hat to winner': 'sinhala_ehata_wenna_',
      'hate the winner': 'sinhala_ehata_wenna_',
      'eight o winner': 'sinhala_ehata_wenna_',
      'eight have winner': 'sinhala_ehata_wenna_',
      'air to win': 'sinhala_ehata_wenna_',
      'a heart to win': 'sinhala_ehata_wenna_',
      'a hat to when': 'sinhala_ehata_wenna_',
      'hate to win': 'sinhala_ehata_wenna_',
      'hate the when': 'sinhala_ehata_wenna_',
      'eight to when': 'sinhala_ehata_wenna_',
      'a how to win': 'sinhala_ehata_wenna_',
      'a hat the winner': 'sinhala_ehata_wenna_',
      'a hat winner': 'sinhala_ehata_wenna_',
      'had to win': 'sinhala_ehata_wenna_',
      'had to winner': 'sinhala_ehata_wenna_',
      'එහාට වෙන්න': 'sinhala_ehata_wenna_',
      'එහාට': 'sinhala_ehata_wenna_',
      'වෙන්න': 'sinhala_ehata_wenna_',

      // 8. Parissamin (Be Careful) -> parissamin  →  පරිස්සමින් (Parissamin - Be Careful)
      'parissamin': 'sinhala_parissamin_',
      'parissamen': 'sinhala_parissamin_',
      'be careful': 'sinhala_parissamin_',
      'careful': 'sinhala_parissamin_',
      'paris man': 'sinhala_parissamin_',
      'paracetamol': 'sinhala_parissamin_',
      'paris samin': 'sinhala_parissamin_',
      'paris amen': 'sinhala_parissamin_',
      'barisamin': 'sinhala_parissamin_',
      'parisam': 'sinhala_parissamin_',
      'paris men': 'sinhala_parissamin_',
      'paris in': 'sinhala_parissamin_',
      'baris amen': 'sinhala_parissamin_',
      'parisa min': 'sinhala_parissamin_',
      'parasite man': 'sinhala_parissamin_',
      'paris summit': 'sinhala_parissamin_',
      'paris some in': 'sinhala_parissamin_',
      'pariss man': 'sinhala_parissamin_',
      'paris mean': 'sinhala_parissamin_',
      'පරිස්සමින්': 'sinhala_parissamin_',
      'පරිස්සමෙන්': 'sinhala_parissamin_',
      'පරිස්සම්': 'sinhala_parissamin_',
    };

    // Prefer an exact recognizer result. Only fall back to a word boundary
    // match when the recognizer returned a short phrase around the keyword.
    for (final target in targets) {
      for (final entry in sinhalaKeywords.entries) {
        final exactMatch = target == entry.key;
        final boundaryMatch = RegExp(
          '(^|\\s)${RegExp.escape(entry.key)}(\\s|\$)',
        ).hasMatch(target);
        if (exactMatch || boundaryMatch) {
          final now = DateTime.now();
          final previous = _lastKeywordTriggerTimes[entry.value];
          if (previous != null &&
              now.difference(previous).inMilliseconds < 1500) {
            return;
          }
          _lastKeywordTriggerTimes[entry.value] = now;
          _lastSpeechTimeMs = now.millisecondsSinceEpoch;

          _transcriptController.add(
              _sinhalaLiveSpeechWord[entry.value] ?? rawText);

          // 2. Pop up ONLY the matching Sinhala emergency card IMMEDIATELY
          unawaited(simulateSoundDetection(
            entry.value,
            confidence: 0.99,
            overrideCooldown: true,
          ));
          return; // STOP! User voice NEVER triggers environmental sounds!
        }
      }
    }

    // Ignore non-keyword speech. Environmental sounds are detected only from
    // microphone PCM by the offline sound classifier below.
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

    // Filter out silence and ambient room noise (Real speech / audio has MaxAmp >= 0.012 or RMS >= 0.004)
    final bool hasSoundEnergy = (maxAmp >= 0.012 || rms >= 0.004);
    // Give the recorder and microphone AGC time to settle. The initial
    // rolling window often contains startup clicks or device noise.
    final bool startupGraceOver = (nowMs - _listeningStartTimeMs >= 1500);

    if (_total16kPushed >= 6000 &&
        startupGraceOver &&
        hasSoundEnergy &&
        // The offline model performs a full 16 kHz FFT and neural inference.
        // Keep the rolling model responsive without processing every audio
        // packet. A shorter cadence reduces the gap between consecutive words.
        (nowMs - _lastMlTimeMs >= 180)) {
      _lastMlTimeMs = nowMs;

      // Extract 1-second rolling window
      final List<double> window1s = List<double>.filled(16000, 0.0);
      double windowMax = 0.0;
      double windowSumSquares = 0.0;
      for (int i = 0; i < 16000; i++) {
        final s = _rollingBuf16k[(_rollingIdx - 16000 + i + 16000) % 16000];
        window1s[i] = s;
        final absS = s.abs();
        if (absS > windowMax) windowMax = absS;
        windowSumSquares += s * s;
      }
      final double windowRms = math.sqrt(windowSumSquares / window1s.length);

      // Do not classify silence, microphone self-noise, or AGC-amplified room
      // noise. This gate is based on the original samples, before gain.
      if (windowRms < 0.0035 || windowMax < 0.015) {
        _pendingSpeechClass = null;
        _pendingSpeechVotes = 0;
        _pendingEnvironmentSound = null;
        _pendingEnvironmentVotes = 0;
        return;
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
        double secondSpeechProb = 0.0;
        for (final s in speechClasses) {
          final p = allP[s] ?? 0.0;
          if (p > bestSpeechProb) {
            secondSpeechProb = bestSpeechProb;
            bestSpeechProb = p;
            bestSpeechClass = s;
          } else if (p > secondSpeechProb) {
            secondSpeechProb = p;
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
        // Treat even a modest speech-class score as speech-like input. This
        // wider gate is important because a single noisy window can otherwise
        // rank a voice as a siren or another environmental sound.
        final bool speechLikely = bestSpeechClass != null &&
            bestSpeechProb >= 0.10 &&
            bestSpeechProb >= bestEnvProb * 0.35;
        if (speechLikely) {
          _lastSpeechTimeMs = nowMs;
        }

        // Check if keyword is detected with high confidence
        final bool isUdaw = bestSpeechClass == 'udaw';
        final bool keywordIsUnambiguous = bestSpeechClass != null &&
            (isUdaw
                ? (bestSpeechProb >= 0.16 && bestSpeechProb > secondSpeechProb)
                : (bestSpeechProb >= 0.18 &&
                    bestSpeechProb >= secondSpeechProb * 1.10 &&
                    bestSpeechProb - secondSpeechProb >= 0.03));

        // Speech energy takes priority over environmental classification.
        if (bestSpeechClass != null &&
            keywordIsUnambiguous &&
            bestSpeechProb >= bestEnvProb * 0.35) {
          _lastSpeechTimeMs = nowMs;
          _pendingEnvironmentSound = null;
          _pendingEnvironmentVotes = 0;

          if (_pendingSpeechClass == bestSpeechClass &&
              nowMs - _pendingSpeechAtMs <= 1200) {
            _pendingSpeechVotes++;
          } else {
            _pendingSpeechClass = bestSpeechClass;
            _pendingSpeechVotes = 1;
          }
          _pendingSpeechAtMs = nowMs;

          // For short keywords like 'udaw' (or high confidence >= 0.22), trigger immediately on 1 window.
          // For lower confidence, 2 windows confirm it.
          final bool shouldTrigger = isUdaw ||
              bestSpeechProb >= 0.22 ||
              _pendingSpeechVotes >= 2;

          if (shouldTrigger) {
            final soundKey = _classToSoundKey[bestSpeechClass];
            if (soundKey != null) {
              final lastKeyword = _lastKeywordTriggerTimes[soundKey];
              final keywordCooldownPassed = lastKeyword == null ||
                  nowMs - lastKeyword.millisecondsSinceEpoch >= 1500;
              if (keywordCooldownPassed) {
                _lastKeywordTriggerTimes[soundKey] =
                    DateTime.fromMillisecondsSinceEpoch(nowMs);
                _transcriptController.add(
                    _sinhalaLiveSpeechWord[soundKey] ?? bestSpeechClass);
                unawaited(simulateSoundDetection(
                  soundKey,
                  confidence: bestSpeechProb.clamp(0.0, 1.0),
                  overrideCooldown: true,
                ));
              }
            }
            _pendingSpeechVotes = 0;
          }
          return;
        }

        _pendingSpeechClass = null;
        _pendingSpeechVotes = 0;

        // Case B: Background Environmental Sound (Ambulance, Fire Truck, Horn, Dog, Baby, Traffic)
        // Evaluated when user is not actively speaking
        // Keep environmental classification gated briefly after a speech
        // window. A spoken keyword can span several model windows; without
        // this hold, the tail of "udaw" may be misclassified as another
        // sound and replace the keyword alert.
        final bool userSpokeRecently = (nowMs - _lastSpeechTimeMs < 2800);

        if (!userSpokeRecently && !speechLikely) {
          // Environmental alert decisions must come from the trained model.
          // The direct frequency shortcut was too eager and produced false
          // cards from room noise and microphone startup artifacts.
          final candidateSound =
              bestEnvClass != null ? envSoundMap[bestEnvClass] : null;

          if (candidateSound != null) {
            const envThresholds = {
              'ambulance_siren': 0.70,
              'fire_truck': 0.85,
              'vehicle_horn': 0.70,
              'baby_crying': 0.70,
              'dog_barking': 0.70,
              'background_traffic': 0.75,
            };
            final double reqProb = envThresholds[bestEnvClass] ?? 0.75;
            final bool trafficValid = (bestEnvClass != 'background_traffic') ||
                (rms >= 0.025 && maxAmp >= 0.10);
            final bool isValid = bestEnvProb >= reqProb &&
                bestEnvProb >= bestSpeechProb * 1.50 &&
                trafficValid;
            final double confidence = bestEnvProb;

            if (isValid) {
              final lastAlert = _lastSoundAlertTimes[candidateSound];
              final bool cooldownPassed = lastAlert == null ||
                  nowMs - lastAlert.millisecondsSinceEpoch >= 2000;

              if (_pendingEnvironmentSound == candidateSound) {
                _pendingEnvironmentVotes++;
              } else {
                _pendingEnvironmentSound = candidateSound;
                _pendingEnvironmentVotes = 1;
              }

              const requiredEnvironmentVotes = 3;
              if (cooldownPassed &&
                  _pendingEnvironmentVotes >= requiredEnvironmentVotes) {
                _lastSoundAlertTimes[candidateSound] =
                    DateTime.fromMillisecondsSinceEpoch(nowMs);
                // Environmental sounds only create an alert card. They are
                // written as the confirmed sound name, never as speech text.
                simulateSoundDetection(candidateSound, confidence: confidence);
              }
            } else {
              _pendingEnvironmentSound = null;
              _pendingEnvironmentVotes = 0;
            }
          } else {
            _pendingEnvironmentSound = null;
            _pendingEnvironmentVotes = 0;
          }
        }
      }
    }
  }

  String? _detectEnvironmentalAcousticSound(List<double> window16k, double maxA, double rms) {
    if (window16k.length < 8000 || rms < 0.02 || maxA < 0.08) return null;

    final int n = window16k.length;
    int zcCount = 0;
    for (int i = 1; i < n; i++) {
      if ((window16k[i] >= 0 && window16k[i - 1] < 0) || (window16k[i] < 0 && window16k[i - 1] >= 0)) {
        zcCount++;
      }
    }
    final double zcr = zcCount / n;

    final centerStart = (n ~/ 2) - 2048;
    const testN = 4096;

    double energyAt(double freq) {
      final double k = (freq * testN / 16000).roundToDouble();
      final double omega = (2.0 * math.pi / testN) * k;
      final double coeff = 2.0 * math.cos(omega);
      double q1 = 0.0, q2 = 0.0;

      for (int i = centerStart; i < centerStart + testN; i++) {
        final double q0 = coeff * q1 - q2 + window16k[i];
        q2 = q1;
        q1 = q0;
      }
      return q1 * q1 + q2 * q2 - q1 * q2 * coeff;
    }

    final double eLow = energyAt(100) + energyAt(150) + energyAt(200) + energyAt(250);
    final double eHorn = energyAt(380) + energyAt(440) + energyAt(500);
    final double eTruck = energyAt(300) + energyAt(550) + energyAt(650);
    final double eSiren = energyAt(750) + energyAt(850) + energyAt(950) + energyAt(1050);
    final double eCry = energyAt(1300) + energyAt(1600) + energyAt(2000) + energyAt(2400);
    final double eBark = energyAt(900) + energyAt(1200) + energyAt(1700);

    final double eTotal = eLow + eHorn + eTruck + eSiren + eCry + 1e-12;
    final double rLow = eLow / eTotal;
    final double rHorn = eHorn / eTotal;
    final double rSiren = eSiren / eTotal;
    final double rCry = eCry / eTotal;

    // Transient bursts check for dog barking
    int subFramesWithSpikes = 0;
    const subLen = 1600;
    for (int sf = 0; sf < 10; sf++) {
      double sfMax = 0.0;
      for (int i = sf * subLen; i < (sf + 1) * subLen; i++) {
        final a = window16k[i].abs();
        if (a > sfMax) sfMax = a;
      }
      if (sfMax > maxA * 0.70) subFramesWithSpikes++;
    }
    final bool isTransientBurst = (subFramesWithSpikes >= 1 && subFramesWithSpikes <= 4);

    // 1. Baby Crying: High-pitch infant vocal cry in 1300-2400 Hz
    if (rCry > 0.35 && zcr > 0.08 && rLow < 0.30) {
      return 'baby crying';
    }

    // 2. Ambulance Siren: Sweeping siren in 750-1050 Hz
    if (rSiren > 0.35 && rLow < 0.25 && !isTransientBurst) {
      return 'ambulance';
    }

    // 3. Vehicle Horn: 380-500 Hz chord blast
    if (rHorn > 0.45 && rLow < 0.30) {
      return 'vehicle horns';
    }

    // 4. Dog Barking: Short acoustic bursts
    if (isTransientBurst && zcr > 0.07 && (eBark / eTotal) > 0.30) {
      return 'dog_bark_dataset';
    }

    // 5. Traffic Noise: Low engine rumble
    if (rLow > 0.60 && zcr < 0.06) {
      return 'traffic';
    }

    // 6. Fire Truck Siren (strictly requires truck energy and low cry ratio)
    if ((eTruck / eTotal) > 0.60 && rLow < 0.30 && rCry < 0.15) {
      return 'fire_truck';
    }

    return null;
  }

  void stopListening() {
    _isListening = false;
    _visualizerTicker?.cancel();
    _visualizerTicker = null;
    _speechSubscription?.cancel();
    _speechSubscription = null;
    _latestSoundVolume = 0.02;
    _waveformController.add([]);

    _recordStreamSub?.cancel();
    _recordStreamSub = null;
    try {
      _speechChannel.invokeMethod('stopListening');
    } catch (_) {}
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
