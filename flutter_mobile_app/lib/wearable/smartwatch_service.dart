import 'package:flutter/foundation.dart';
import '../models/detection_event.dart';
import '../models/alert_level.dart';
import '../services/notification_service.dart';
import '../alerts/vibration_manager.dart';
import '../ai/audio_capture_interface.dart';
import '../ai/audio_capture_bridge.dart';
import 'ble_watch_controller.dart';

enum SmartwatchConnectMode {
  notificationMirror,
  directBLE,
}

class SmartwatchService extends ChangeNotifier {
  static final SmartwatchService _instance = SmartwatchService._internal();
  factory SmartwatchService() => _instance;
  SmartwatchService._internal() {
    _bridge = getAudioCaptureBridge();
  }

  late final AudioCaptureInterface _bridge;
  final NotificationService _notificationService = NotificationService();
  final VibrationManager _vibrationManager = VibrationManager();
  final BleWatchController _bleController = BleWatchController();

  SmartwatchConnectMode _connectMode = SmartwatchConnectMode.directBLE;
  bool _isDeviceConnected = true;
  String _deviceName = "Yesido IO39 Smartwatch";
  bool _isTestingVibration = false;

  SmartwatchConnectMode get connectMode => _connectMode;
  bool get isDeviceConnected => _isDeviceConnected;
  String get deviceName => _bleController.isConnected ? _bleController.connectedDeviceName : _deviceName;
  bool get isTestingVibration => _isTestingVibration;

  String get connectionStatusText {
    if (!_isDeviceConnected) {
      return "Disconnected - Standalone Mobile Alert Mode";
    }
    return "Connected: $deviceName (Direct BLE & Notification Sync Active)";
  }

  void toggleConnection() {
    _isDeviceConnected = !_isDeviceConnected;
    notifyListeners();
  }

  void setConnection(bool connected) {
    _isDeviceConnected = connected;
    notifyListeners();
  }

  void toggleMode() {
    if (_connectMode == SmartwatchConnectMode.notificationMirror) {
      _connectMode = SmartwatchConnectMode.directBLE;
    } else {
      _connectMode = SmartwatchConnectMode.notificationMirror;
    }
    notifyListeners();
  }

  Future<void> connectWatchViaBle() async {
    // 1. Direct BLE GATT scan & connect
    final nativeConnected = await _bleController.scanAndConnect();
    // 2. Web bridge BLE
    final webConnected = await _bridge.connectBleWatch();

    _isDeviceConnected = nativeConnected || webConnected;
    notifyListeners();
  }

  /// Send test vibration pulse to the watch so user can feel it on their skin
  Future<void> testWatchVibration({AlertLevel priority = AlertLevel.high}) async {
    _isTestingVibration = true;
    notifyListeners();

    // 1. Send Android High-Priority Notification with Vibration Pattern to watch
    final testEvent = DetectionEvent(
      id: "test_${DateTime.now().millisecondsSinceEpoch}",
      rawClass: "udaw",
      titleEnglish: "HELP! (Urgent Watch Alert Test)",
      titleSinhala: "හදිසි අවදානම් පරීක්ෂාව (\"උදව්\")",
      priority: priority,
      confidence: 0.98,
      timestamp: DateTime.now(),
      avatarGuidanceEnglish: "Tactile vibration pattern dispatched to Yesido IO39 Smartwatch.",
      avatarGuidanceSinhala: "ස්මාර්ට් ඔරලෝසුව වෙත කම්පන සංඥාව යවන ලදී.",
    );
    await _notificationService.sendEventNotification(testEvent);

    // 2. Native Direct BLE Motor Command Packet
    await _bleController.sendVibrationCommand(priority.name);

    // 3. Phone Hardware Haptic Vibration
    await _vibrationManager.triggerHapticPattern(priority);

    // 4. Web BLE Vibration Bridge with Warning Message
    _bridge.sendWatchVibration(
      priority.name,
      title: "🚨 YESIDO IO39 TACTILE VIBRATION TEST",
      sinhala: "ස්මාර්ට් ඔරලෝසු කම්පන පරීක්ෂාව - හදිසි ඇඟවීම",
    );

    await Future.delayed(const Duration(milliseconds: 1500));
    _isTestingVibration = false;
    notifyListeners();
  }

  /// Dispatch event alert to Yesido IO39 smartwatch
  Future<bool> sendWatchAlert(DetectionEvent event) async {
    // 1. Send notifications to notification center (read by watch companion app)
    await _notificationService.sendEventNotification(event);

    // 2. Native Direct BLE Motor Command Packet if raw BLE device is connected
    if (_isDeviceConnected) {
      await _bleController.sendVibrationCommand(event.priority.name, soundClass: event.rawClass);
    }

    // 3. Web BLE Bridge with English-first Latin letters and Sinhala for Yesido Watch
    _bridge.sendWatchVibration(
      event.priority.name,
      title: '🚨 [${event.priority.name.toUpperCase()}] ${event.titleEnglish} (${event.titleSinhala})',
      sinhala: '${event.titleEnglish.toUpperCase()}: ${event.titleSinhala} - ${event.avatarGuidanceSinhala}',
      soundClass: event.rawClass,
    );

    return true;
  }
}
