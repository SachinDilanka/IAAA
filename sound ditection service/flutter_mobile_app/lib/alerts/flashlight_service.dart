import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert_level.dart';

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

  Future<void> triggerFlashlightPattern(AlertLevel priority) async {
    if (!_isFlashlightEnabled) return;

    try {
      List<int> pattern;
      switch (priority) {
        case AlertLevel.high:
          pattern = [0, 600, 120, 600, 120, 800, 120, 800];
          break;
        case AlertLevel.medium:
          pattern = [0, 500, 130, 500, 130, 500];
          break;
        case AlertLevel.low:
          pattern = [0, 400, 150, 400];
          break;
      }

      await _channel.invokeMethod('flashPattern', {'pattern': pattern});
    } catch (e) {
      print('Flashlight pattern error: $e');
    }
  }

  Future<void> cancelFlashlight() async {
    try {
      await _channel.invokeMethod('turnOff');
    } catch (_) {}
  }
}

