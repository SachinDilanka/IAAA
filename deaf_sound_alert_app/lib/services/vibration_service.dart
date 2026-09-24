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
          // Ultra-strong triple pulse for Deaf Users
          await Vibration.vibrate(
            pattern: [0, 800, 150, 800, 150, 1200],
            intensities: [0, 255, 0, 255, 0, 255],
          );
          break;
        case PriorityLevel.medium:
          // Strong double pulse
          await Vibration.vibrate(
            pattern: [0, 500, 200, 500],
            intensities: [0, 255, 0, 255],
          );
          break;
        case PriorityLevel.low:
          // Single pulse
          await Vibration.vibrate(
            pattern: [0, 300],
            intensities: [0, 200],
          );
          break;
      }
    } catch (e) {
      try {
        await Vibration.vibrate(duration: 500);
      } catch (_) {}
    }
  }

  Future<void> cancelVibration() async {
    try {
      await Vibration.cancel();
    } catch (_) {}
  }
}

