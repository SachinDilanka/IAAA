import 'package:flutter/services.dart';
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
    // 1. Instant tactile HapticFeedback based on priority level
    try {
      switch (priority) {
        case PriorityLevel.high:
          await HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 150), () => HapticFeedback.heavyImpact());
          Future.delayed(const Duration(milliseconds: 300), () => HapticFeedback.heavyImpact());
          break;
        case PriorityLevel.medium:
          await HapticFeedback.mediumImpact();
          Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.mediumImpact());
          break;
        case PriorityLevel.low:
          await HapticFeedback.lightImpact();
          break;
      }
    } catch (_) {}

    if (!_hasVibrator) return;

    // 2. Strong device vibration motor pattern based on priority level
    try {
      switch (priority) {
        case PriorityLevel.high:
          // Heavy SOS Triple Burst Pattern for Deaf Users (Emergency: Udaw, Fire, Siren, Save Me)
          await Vibration.vibrate(
            pattern: [0, 500, 100, 500, 100, 700],
            intensities: [0, 255, 0, 255, 0, 255],
          );
          break;
        case PriorityLevel.medium:
          // Heavy Double Pulse Pattern for Deaf Users (Warning: Balaagena, Ehata Wenna, Horn, Barking)
          await Vibration.vibrate(
            pattern: [0, 400, 150, 400],
            intensities: [0, 240, 0, 240],
          );
          break;
        case PriorityLevel.low:
          // Single Distinct Pulse Pattern for Deaf Users (Traffic, Road)
          await Vibration.vibrate(
            pattern: [0, 300],
            intensities: [0, 200],
          );
          break;
      }
    } catch (e) {
      try {
        await Vibration.vibrate(duration: 800);
      } catch (_) {}
    }
  }

  Future<void> cancelVibration() async {
    try {
      await Vibration.cancel();
    } catch (_) {}
  }
}
