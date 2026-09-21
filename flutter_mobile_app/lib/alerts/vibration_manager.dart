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
      final bool hasAmplitude = await Vibration.hasAmplitudeControl() == true;

      if (priority == AlertLevel.high ||
          sound.contains('fire') ||
          sound.contains('ginna') ||
          sound.contains('ambulance') ||
          sound.contains('siren') ||
          sound.contains('udaw') ||
          sound.contains('beeraganna') ||
          sound.contains('anathurak') ||
          sound.contains('horn') ||
          sound.contains('scream')) {
        // High priority: Ultra-Strong Repeated Heavy Pulse for Deaf Users
        _activePatternDescription = "🚨 HIGH EMERGENCY: Heavy Multi-Pulse Tactile Vibration (255 Max Amplitude)";
        if (hasVibrator) {
          if (hasAmplitude) {
            await Vibration.vibrate(
              pattern: [0, 1000, 150, 1000, 150, 1200],
              intensities: [0, 255, 0, 255, 0, 255],
            );
          } else {
            await Vibration.vibrate(pattern: [0, 1000, 150, 1000, 150, 1200]);
          }
        }
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 300));
        await HapticFeedback.heavyImpact();
      } else if (priority == AlertLevel.medium ||
          sound.contains('baby') ||
          sound.contains('karadarayak') ||
          sound.contains('balagena') ||
          sound.contains('parissamin') ||
          sound.contains('ehata')) {
        // Medium priority: Strong 3-Pulse Rhythmic Caution Vibration
        _activePatternDescription = "⚠️ MEDIUM CAUTION: 3-Pulse Strong Vibration (255 Amplitude)";
        if (hasVibrator) {
          if (hasAmplitude) {
            await Vibration.vibrate(
              pattern: [0, 600, 150, 600, 150, 600],
              intensities: [0, 255, 0, 255, 0, 255],
            );
          } else {
            await Vibration.vibrate(pattern: [0, 600, 150, 600, 150, 600]);
          }
        }
        await HapticFeedback.heavyImpact();
      } else {
        // Low priority: Strong Double-Tap Vibrations
        _activePatternDescription = "ℹ️ LOW NOTICE: Strong Double Pulse";
        if (hasVibrator) {
          if (hasAmplitude) {
            await Vibration.vibrate(
              pattern: [0, 450, 150, 450],
              intensities: [0, 255, 0, 255],
            );
          } else {
            await Vibration.vibrate(pattern: [0, 450, 150, 450]);
          }
        }
        await HapticFeedback.mediumImpact();
      }
    } catch (e) {
      try {
        await HapticFeedback.heavyImpact();
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
