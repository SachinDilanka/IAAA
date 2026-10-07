import 'package:vibration/vibration.dart';
import '../models/detected_sound.dart';

class VibrationService {
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;
  VibrationService._internal();

  bool _hasVibrator = false;

  Future<void> init() async {
    try {
      final res = await Vibration.hasVibrator();
      _hasVibrator = res == true;
    } catch (e) {
      _hasVibrator = true;
    }
  }

  Future<void> triggerVibration(PriorityLevel priority) async {
    if (!_hasVibrator) return;

    try {
      switch (priority) {
        case PriorityLevel.high:
          // Heavy SOS Triple Burst Pattern for Deaf Users (Emergency: Udaw, Fire, Siren, Save Me)
          await Vibration.vibrate(
            pattern: [0, 450, 120, 450, 120, 700],
            intensities: [0, 255, 0, 255, 0, 255],
          );
          break;
        case PriorityLevel.medium:
          // Heavy Double Pulse Pattern for Deaf Users (Warning: Balaagena, Ehata Wenna, Horn, Barking)
          await Vibration.vibrate(
            pattern: [0, 350, 150, 350],
            intensities: [0, 240, 0, 240],
          );
          break;
        case PriorityLevel.low:
          // Single Distinct Pulse Pattern for Deaf Users (Traffic, Road)
          await Vibration.vibrate(
            pattern: [0, 250],
            intensities: [0, 180],
          );
          break;
      }
    } catch (e) {
      try {
        await Vibration.vibrate(duration: 600);
      } catch (_) {}
    }
  }

  Future<void> cancelVibration() async {
    try {
      await Vibration.cancel();
    } catch (_) {}
  }
}

