import 'package:flutter/foundation.dart';
import '../models/alert_level.dart';
import '../models/detection_event.dart';

enum AvatarState {
  idle,
  listening,
  highAlert,
  mediumAlert,
  lowAlert,
}

class AvatarController extends ChangeNotifier {
  AvatarState _state = AvatarState.idle;
  DetectionEvent? _currentEvent;
  String _englishMessage = "3D AI Avatar Ready. Listening for Sinhala keywords and emergency sounds...";
  String _sinhalaMessage = "3D AI සහයිකාව සූදානම්. සිංහල හදිසි වචන සහ ශබ්ද සඳහා සවන් දෙමින් පවතී...";

  bool _is3DExpanded = true;
  double _manualYaw = 0.0;
  double _manualPitch = 0.05;

  AvatarState get state => _state;
  DetectionEvent? get currentEvent => _currentEvent;
  String get englishMessage => _englishMessage;
  String get sinhalaMessage => _sinhalaMessage;
  bool get is3DExpanded => _is3DExpanded;
  double get manualYaw => _manualYaw;
  double get manualPitch => _manualPitch;

  void toggle3DExpanded() {
    _is3DExpanded = !_is3DExpanded;
    notifyListeners();
  }

  void update3DCamera(double yaw, double pitch) {
    _manualYaw = yaw;
    _manualPitch = pitch;
    notifyListeners();
  }

  void setListeningState() {
    _state = AvatarState.listening;
    _englishMessage = "Real-time 3D AI Monitoring Active... Listening for emergency sounds & Sinhala keywords";
    _sinhalaMessage = "නොබැඳි 3D AI පද්ධතිය ක්‍රියාත්මකයි... හදිසි ශබ්ද සහ සිංහල වචන සඳහා සවන් දෙමින් පවතී";
    notifyListeners();
  }

  void handleDetectedEvent(DetectionEvent event) {
    _currentEvent = event;
    switch (event.priority) {
      case AlertLevel.high:
        _state = AvatarState.highAlert;
        break;
      case AlertLevel.medium:
        _state = AvatarState.mediumAlert;
        break;
      case AlertLevel.low:
        _state = AvatarState.lowAlert;
        break;
      case AlertLevel.none:
        _state = AvatarState.listening;
        break;
    }

    _englishMessage = event.avatarGuidanceEnglish;
    _sinhalaMessage = event.avatarGuidanceSinhala;
    notifyListeners();
  }

  void resetToIdle() {
    _state = AvatarState.idle;
    _currentEvent = null;
    _englishMessage = "3D AI Avatar Standby. Listening for Sinhala keywords and emergency sounds...";
    _sinhalaMessage = "3D AI සහයිකාව සූදානම්. සිංහල හදිසි වචන සහ ශබ්ද සඳහා සවන් දෙමින් පවතී...";
    notifyListeners();
  }
}
