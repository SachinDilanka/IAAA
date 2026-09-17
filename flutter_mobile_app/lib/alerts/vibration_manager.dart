import 'dart:async';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../models/alert_level.dart';

class VibrationManager {
  static final VibrationManager _instance = VibrationManager._internal();
  factory VibrationManager() => _instance;
  VibrationManager._internal();

  Timer? _activeVibrationTimer;
  bool _isVibrating = false;
  String _activePatternDescription = "Normal - No Active Vibration";

  bool get isVibrating => _isVibrating;
  String get activePatternDescription => _activePatternDescription;

  /// Triggers distinct tactile vibration pulse patterns according to sound type & event priority level
  Future<void> triggerHapticPattern(AlertLevel priority, {String? rawClass}) async {
    cancel(); // Cancel any existing vibration sequence

    _isVibrating = true;
    final sound = (rawClass ?? '').toLowerCase().trim();

    try {
      final bool hasVibrator = await Vibration.hasVibrator() == true;

      if (priority == AlertLevel.high ||
          sound.contains('fire') ||
          sound.contains('ginna') ||
          sound.contains('ambulance') ||
          sound.contains('siren') ||
          sound.contains('udaw') ||
          sound.contains('beeraganna') ||
          sound.contains('anathurak') ||
          sound.contains('nawaththanna') ||
          sound.contains('horn') ||
          sound.contains('scream')) {
        // High priority: Long strong vibration
        _activePatternDescription = "🚨 HIGH EMERGENCY: Long Sustained Vibration";
        if (hasVibrator) {
          await Vibration.vibrate(pattern: [0, 1200, 250, 1200]);
        }
      } else if (priority == AlertLevel.medium ||
          sound.contains('baby') ||
          sound.contains('karadarayak') ||
          sound.contains('balagena') ||
          sound.contains('parissamin')) {
        // Medium priority: "bit-bit" rhythmic double vibration
        _activePatternDescription = "⚠️ MEDIUM CAUTION: Rhythmic Bit-Bit Double Pulse";
        if (hasVibrator) {
          await Vibration.vibrate(pattern: [0, 320, 140, 320]);
        }
      } else {
        // Low priority: Short single vibration
        _activePatternDescription = "ℹ️ LOW NOTICE: Short Quick Tap";
        if (hasVibrator) {
          await Vibration.vibrate(duration: 220);
        }
      }

      // Always execute HapticFeedback in parallel for additional hardware haptics
      await HapticFeedback.vibrate();
    } catch (e) {
      try {
        await HapticFeedback.vibrate();
      } catch (_) {}
    } finally {
      _isVibrating = false;
    }
  }

  void cancel() {
    try {
      Vibration.cancel();
    } catch (_) {}
    _activeVibrationTimer?.cancel();
    _activeVibrationTimer = null;
    _isVibrating = false;
  }
}
