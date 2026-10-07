import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/detected_sound.dart';

class FlashlightService {
  static final FlashlightService _instance = FlashlightService._internal();
  factory FlashlightService() => _instance;
  FlashlightService._internal();

  static const MethodChannel _channel = MethodChannel('com.deafalert.app/flashlight');

  bool _isFlashlightEnabled = true;
  bool _hasFlashlight = false;

  bool get isFlashlightEnabled => _isFlashlightEnabled;
  bool get hasFlashlight => _hasFlashlight;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isFlashlightEnabled = prefs.getBool('flashlight_enabled') ?? true;
      _hasFlashlight = await _channel.invokeMethod<bool>('hasFlashlight') ?? true;
    } catch (e) {
      _hasFlashlight = true;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _isFlashlightEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('flashlight_enabled', enabled);
    } catch (_) {}
  }

  /// Flashes camera flashlight based on priority level synced with vibration patterns
  Future<void> triggerFlashlightPattern(PriorityLevel priority) async {
    if (!_isFlashlightEnabled) return;

    try {
      List<int> pattern;
      switch (priority) {
        case PriorityLevel.high:
          // Synced with High Priority SOS Triple Burst Vibration: [0, 450, 120, 450, 120, 700]
          pattern = [0, 450, 120, 450, 120, 700];
          break;
        case PriorityLevel.medium:
          // Synced with Medium Priority Double Pulse Caution Vibration: [0, 350, 150, 350]
          pattern = [0, 350, 150, 350];
          break;
        case PriorityLevel.low:
          // Synced with Low Priority Single Pulse Notice Vibration: [0, 250]
          pattern = [0, 250];
          break;
      }

      await _channel.invokeMethod('flashPattern', {'pattern': pattern});
    } catch (_) {}
  }

  Future<void> cancelFlashlight() async {
    try {
      await _channel.invokeMethod('turnOff');
    } catch (_) {}
  }
}

