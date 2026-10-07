import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../models/detected_sound.dart';

class VibrationService {
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;
  VibrationService._internal();

  bool _hasVibrator = false;
  bool _hasAmplitude = false;

  Future<void> init() async {
    try {
      _hasVibrator = await Vibration.hasVibrator() == true;
      _hasAmplitude = await Vibration.hasAmplitudeControl() == true;
    } catch (e) {
      _hasVibrator = true;
      _hasAmplitude = true;
    }
  }

  /// Triggers priority-based ultra-strong, distinct tactile vibration patterns specially designed for deaf users
  Future<void> triggerVibration(PriorityLevel priority) async {
    if (!_hasVibrator) return;

    try {
      switch (priority) {
        case PriorityLevel.high:
          // Maximum Intensity 5-Burst SOS Emergency Vibration for Deaf Users (Udaw, Fire, Siren, Save Me, Danger)
          if (_hasAmplitude) {
            await Vibration.vibrate(
              pattern: [0, 800, 100, 800, 100, 800, 100, 800, 100, 1000],
              intensities: [0, 255, 0, 255, 0, 255, 0, 255, 0, 255],
            );
          } else {
            await Vibration.vibrate(pattern: [0, 800, 100, 800, 100, 800, 100, 800, 100, 1000]);
          }
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 200));
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 200));
          await HapticFeedback.heavyImpact();
          break;

        case PriorityLevel.medium:
          // Heavy 3-Pulse Caution Pattern for Deaf Users (Balaagena, Karadarayak, Ehata Wenna, Horn, Barking, Baby Crying)
          if (_hasAmplitude) {
            await Vibration.vibrate(
              pattern: [0, 600, 150, 600, 150, 600],
              intensities: [0, 255, 0, 255, 0, 255],
            );
          } else {
            await Vibration.vibrate(pattern: [0, 600, 150, 600, 150, 600]);
          }
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 250));
          await HapticFeedback.heavyImpact();
          break;

        case PriorityLevel.low:
          // Strong Double Pulse Notice Pattern for Deaf Users (Parissamin, Traffic, Road)
          if (_hasAmplitude) {
            await Vibration.vibrate(
              pattern: [0, 450, 150, 450],
              intensities: [0, 255, 0, 255],
            );
          } else {
            await Vibration.vibrate(pattern: [0, 450, 150, 450]);
          }
          await HapticFeedback.heavyImpact();
          break;
      }
    } catch (e) {
      try {
        await Vibration.vibrate(duration: 1000);
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }

  Future<void> cancelVibration() async {
    try {
      await Vibration.cancel();
    } catch (_) {}
  }
}

