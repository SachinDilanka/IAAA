import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Permission status enumeration for clean presentation and testability.
enum LocationServiceStatus {
  searching,
  tracking,
  lowAccuracy,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

/// Interface for real-time location streaming and permission management.
abstract class ILocationService {
  Stream<Position> get positionStream;
  LocationServiceStatus get status;
  String get statusMessage;
  Future<bool> initAndRequestPermission();
  void pause();
  void resume();
  void dispose();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

/// Concrete implementation using the geolocator plugin.
class LocationService with WidgetsBindingObserver implements ILocationService {
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();
  StreamSubscription<Position>? _positionSubscription;

  LocationServiceStatus _status = LocationServiceStatus.searching;
  String _statusMessage = 'GPS: searching...';
  bool _isPaused = false;

  @override
  Stream<Position> get positionStream => _positionController.stream;

  @override
  LocationServiceStatus get status => _status;

  @override
  String get statusMessage => _statusMessage;

  LocationService() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      pause();
    } else if (state == AppLifecycleState.resumed) {
      resume();
      // Re-check permissions in case user updated them in device settings
      initAndRequestPermission();
    }
  }

  @override
  Future<bool> initAndRequestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _status = LocationServiceStatus.serviceDisabled;
        _statusMessage = 'GPS is turned off. Please enable Location Services in device settings.';
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _status = LocationServiceStatus.permissionDenied;
          _statusMessage = 'Location permission denied. Real-time venue detection is unavailable.';
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _status = LocationServiceStatus.permissionDeniedForever;
        _statusMessage = 'Location permission is permanently denied. Please enable in App Settings.';
        return false;
      }

      _status = LocationServiceStatus.tracking;
      _statusMessage = 'GPS active';
      _startStream();
      return true;
    } catch (e) {
      _status = LocationServiceStatus.error;
      _statusMessage = 'Location service error: $e';
      return false;
    }
  }

  void _startStream() {
    _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // ~10 metres as specified
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        if (!_positionController.isClosed) {
          _positionController.add(position);
        }
      },
      onError: (dynamic error) {
        _status = LocationServiceStatus.error;
        _statusMessage = 'GPS error: $error';
        if (kDebugMode) {
          print('Geolocator stream error: $error');
        }
      },
    );
  }

  @override
  void pause() {
    if (!_isPaused) {
      _positionSubscription?.pause();
      _isPaused = true;
    }
  }

  @override
  void resume() {
    if (_isPaused) {
      _positionSubscription?.resume();
      _isPaused = false;
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    _positionController.close();
  }
}
