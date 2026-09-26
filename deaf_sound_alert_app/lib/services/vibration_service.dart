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
          // Strong double pulse (short 450ms pattern so mic input never clips)
          await Vibration.vibrate(
            pattern: [0, 200, 100, 150],
            intensities: [0, 255, 0, 255],
          );
          break;
        case PriorityLevel.medium:
          // Single medium pulse (200ms)
          await Vibration.vibrate(
            pattern: [0, 200],
            intensities: [0, 200],
          );
          break;
        case PriorityLevel.low:
          // Single light pulse (100ms)
          await Vibration.vibrate(
            pattern: [0, 100],
            intensities: [0, 150],
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

