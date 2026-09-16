import 'dart:async';
import 'package:flutter/services.dart';
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
      if (sound.contains('fire') || sound.contains('ginna')) {
        _activePatternDescription = "🔥 FIRE ALARM: Rapid High-Frequency Staccato Pulse";
        await _executeFireAlarmSequence();
      } else if (sound.contains('ambulance') || sound.contains('siren')) {
        _activePatternDescription = "🚑 AMBULANCE: Alternating Two-Tone Wailing Rhythm";
        await _executeAmbulanceSequence();
      } else if (sound.contains('udaw') || sound.contains('beeraganna') || sound.contains('anathurak') || sound.contains('scream')) {
        _activePatternDescription = "🆘 DISTRESS CALL: Continuous Emergency SOS Pulses";
        await _executeHighPrioritySequence();
      } else if (sound.contains('horn')) {
        _activePatternDescription = "🚗 VEHICLE HORN: Strong Double Blast Warning";
        await _executeVehicleHornSequence();
      } else if (sound.contains('baby') || sound.contains('karadarayak') || sound.contains('balagena') || sound.contains('parissamin')) {
        _activePatternDescription = "👶 BABY / CAUTION: Gentle Rhythmic Double Pulse";
        await _executeMediumPrioritySequence();
      } else if (sound.contains('bark') || sound.contains('dog')) {
        _activePatternDescription = "🐕 DOG BARK: Sharp Double-Tap Pulse";
        await _executeDogBarkSequence();
      } else if (sound.contains('traffic') || sound.contains('road')) {
        _activePatternDescription = "🚦 TRAFFIC / ROAD: Low Ambient Rumble Tap";
        await _executeLowPrioritySequence();
      } else {
        switch (priority) {
          case AlertLevel.high:
            _activePatternDescription = "🔴 HIGH URGENCY: Triple Heavy Staccato Pulse";
            await _executeHighPrioritySequence();
            break;
          case AlertLevel.medium:
            _activePatternDescription = "🟡 MEDIUM URGENCY: Double Caution Pulse";
            await _executeMediumPrioritySequence();
            break;
          case AlertLevel.low:
            _activePatternDescription = "🟢 LOW URGENCY: Single Gentle Pulse";
            await _executeLowPrioritySequence();
            break;
          case AlertLevel.none:
            _activePatternDescription = "Normal - Idle";
            _isVibrating = false;
            break;
        }
      }
    } catch (e) {
      // Graceful fallback for devices without vibration hardware
    } finally {
      _isVibrating = false;
    }
  }

  /// Fire Alarm Sequence: Rapid Staccato Bursts
  Future<void> _executeFireAlarmSequence() async {
    for (int i = 0; i < 5; i++) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 70));
    }
    await Future.delayed(const Duration(milliseconds: 200));
    for (int i = 0; i < 5; i++) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 70));
    }
  }

  /// Ambulance Sequence: Long-Short Alternating Siren Cadence
  Future<void> _executeAmbulanceSequence() async {
    await HapticFeedback.vibrate();
    await Future.delayed(const Duration(milliseconds: 350));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.vibrate();
    await Future.delayed(const Duration(milliseconds: 350));
    await HapticFeedback.mediumImpact();
  }

  /// Vehicle Horn Sequence: Strong Double Honk Blast
  Future<void> _executeVehicleHornSequence() async {
    await HapticFeedback.heavyImpact();
    await HapticFeedback.vibrate();
    await Future.delayed(const Duration(milliseconds: 280));
    await HapticFeedback.heavyImpact();
    await HapticFeedback.vibrate();
  }

  /// Dog Bark Sequence: Quick Crisp Double Tap
  Future<void> _executeDogBarkSequence() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
  }

  /// High Priority Emergency SOS Sequence
  Future<void> _executeHighPrioritySequence() async {
    for (int i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 140));
    }
    await Future.delayed(const Duration(milliseconds: 200));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.heavyImpact();
  }

  /// Medium Priority Sequence: 2 Moderate Pulses
  Future<void> _executeMediumPrioritySequence() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 180));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 180));
    await HapticFeedback.selectionClick();
  }

  /// Low Priority Sequence: Single Discrete Tap
  Future<void> _executeLowPrioritySequence() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.selectionClick();
  }

  void cancel() {
    _activeVibrationTimer?.cancel();
    _activeVibrationTimer = null;
    _isVibrating = false;
  }
}
