import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleWatchController {
  static final BleWatchController _instance = BleWatchController._internal();
  factory BleWatchController() => _instance;
  BleWatchController._internal();

  BluetoothDevice? _connectedDevice;
  final List<BluetoothCharacteristic> _alertCharacteristics = [];
  bool _isConnecting = false;

  bool get isConnected => _connectedDevice != null;
  String get connectedDeviceName => _connectedDevice?.platformName ?? "No Watch Connected";

  /// Scan and auto-connect to Yesido IO39 / XO FIT / Smartwatch over BLE
  Future<bool> scanAndConnect({String? targetName}) async {
    if (kIsWeb) return false;
    if (_isConnecting) return false;
    _isConnecting = true;

    try {
      if (await FlutterBluePlus.isSupported == false) {
        _isConnecting = false;
        return false;
      }

      // Turn on Bluetooth if needed
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {}

      // Check already connected system devices
      try {
        final connectedList = FlutterBluePlus.connectedDevices;
        for (var device in connectedList) {
          final name = device.platformName.toLowerCase();
          if (name.contains("yesido") ||
              name.contains("io39") ||
              name.contains("xo") ||
              name.contains("watch") ||
              name.contains("fit")) {
            await _setupDeviceCharacteristics(device);
            _connectedDevice = device;
            _isConnecting = false;
            return true;
          }
        }
      } catch (e) {}

      // Start BLE scan
      Completer<bool> scanCompleter = Completer();

      var subscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          final devName = r.device.platformName.toLowerCase();
          if (devName.contains("yesido") ||
              devName.contains("io39") ||
              devName.contains("xo") ||
              devName.contains("watch") ||
              devName.contains("fit")) {
            await FlutterBluePlus.stopScan();
            try {
              await r.device.connect(timeout: const Duration(seconds: 5), autoConnect: false);
              await _setupDeviceCharacteristics(r.device);
              _connectedDevice = r.device;
              if (!scanCompleter.isCompleted) scanCompleter.complete(true);
            } catch (e) {
              if (!scanCompleter.isCompleted) scanCompleter.complete(false);
            }
            break;
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      await Future.delayed(const Duration(seconds: 4));
      await FlutterBluePlus.stopScan();
      await subscription.cancel();

      if (!scanCompleter.isCompleted) scanCompleter.complete(_connectedDevice != null);
      _isConnecting = false;
      return await scanCompleter.future;
    } catch (e) {
      _isConnecting = false;
      return false;
    }
  }

  Future<void> _setupDeviceCharacteristics(BluetoothDevice device) async {
    _alertCharacteristics.clear();
    try {
      final services = await device.discoverServices();
      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.properties.write || c.properties.writeWithoutResponse) {
            _alertCharacteristics.add(c);
          }
        }
      }
    } catch (e) {}
  }

  /// Write vibration motor commands directly to Yesido IO39 / Smartwatch with differentiated patterns
  Future<void> sendVibrationCommand(String priority, {String? soundClass}) async {
    if (kIsWeb) return;
    if (_alertCharacteristics.isEmpty) return;

    final p = priority.toUpperCase();
    final isHigh = (p == 'HIGH');
    final isMedium = (p == 'MEDIUM');
    final alertLevelVal = isHigh ? 2 : 1;

    // Immediate Alert Payload: [0x02 = High Alert, 0x01 = Mild Alert]
    final payloadImmediate = [alertLevelVal];
    // XO FIT / Nordic UART Vibrate Command: [0xAB, 0x00, 0x04, 0xFF, 0x31, 0x01, alertLevelVal]
    final payloadXO = [0xAB, 0x00, 0x04, 0xFF, 0x31, 0x01, alertLevelVal];
    // FitPro / JL Motor Command: [0xCD, 0x00, 0x03, 0x05, 0x01, alertLevelVal]
    final payloadFitPro = [0xCD, 0x00, 0x03, 0x05, 0x01, alertLevelVal];
    // Da Fit Vibrate Command: High = 10 pulses (0x0A), Medium = 4 pulses (0x04), Low = 1 pulse (0x01)
    final vibrateCount = isHigh ? 0x0A : (isMedium ? 0x04 : 0x01);
    final payloadDaFit = [0x04, 0x01, vibrateCount];

    Future<void> sendPulse() async {
      for (var c in _alertCharacteristics) {
        try {
          final uuid = c.uuid.toString().toLowerCase();
          if (uuid.contains('2a06')) {
            await c.write(payloadImmediate, withoutResponse: c.properties.writeWithoutResponse);
          } else if (uuid.contains('6e400002') || uuid.contains('fff1') || uuid.contains('ffe1')) {
            await c.write(payloadXO, withoutResponse: true);
            await c.write(payloadFitPro, withoutResponse: true);
          } else {
            await c.write(payloadDaFit, withoutResponse: true);
          }
        } catch (e) {}
      }
    }

    if (isHigh) {
      // High: Long sustained vibration on wrist (4 pulses spaced out)
      await sendPulse();
      Future.delayed(const Duration(milliseconds: 350), () => sendPulse());
      Future.delayed(const Duration(milliseconds: 800), () => sendPulse());
      Future.delayed(const Duration(milliseconds: 1300), () => sendPulse());
    } else if (isMedium) {
      // Medium: "Bit-bit" rhythmic double pulse on wrist
      await sendPulse();
      Future.delayed(const Duration(milliseconds: 320), () => sendPulse());
    } else {
      // Low: Short single tap on wrist
      await sendPulse();
    }
  }
}
