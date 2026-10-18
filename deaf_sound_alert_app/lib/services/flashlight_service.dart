import 'package:flutter/services.dart';
import '../models/detected_sound.dart';

class FlashlightService {
  static final FlashlightService _instance = FlashlightService._internal();
  factory FlashlightService() => _instance;
  FlashlightService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.deafalert.app.deaf_sound_alert_app/flashlight');

  bool _isFlashEnabled = true;
  bool get isFlashEnabled => _isFlashEnabled;

  void setFlashEnabled(bool enabled) {
    _isFlashEnabled = enabled;
  }

  /// Triggers hardware flashlight strobe pulses based on alert priority
  /// - High: 3 rapid urgent strobe flashes (150ms on / 100ms off)
  /// - Medium: 2 warning flashes (250ms on / 150ms off)
  /// - Low: 1 gentle flash (300ms on)
  Future<void> triggerFlashlight(PriorityLevel priority) async {
    if (!_isFlashEnabled) return;

    try {
      int count;
      int onMs;
      int offMs;

      switch (priority) {
        case PriorityLevel.high:
          count = 3;
          onMs = 150;
          offMs = 100;
          break;
        case PriorityLevel.medium:
          count = 2;
          onMs = 250;
          offMs = 150;
          break;
        case PriorityLevel.low:
          count = 1;
          onMs = 300;
          offMs = 100;
          break;
      }

      await _channel.invokeMethod('strobeTorch', {
        'count': count,
        'onMs': onMs,
        'offMs': offMs,
      });
    } catch (_) {}
  }
}

