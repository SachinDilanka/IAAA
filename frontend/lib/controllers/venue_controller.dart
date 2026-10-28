import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/communication_models.dart';
import '../data/communication_data.dart';
import '../data/venue_data.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/suggest_api.dart';

/// Haversine formula to compute distance in meters between two coordinates.
double calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const double r = 6371000.0; // Earth radius in meters
  final double dLat = (lat2 - lat1) * (math.pi / 180.0);
  final double dLon = (lon2 - lon1) * (math.pi / 180.0);
  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * (math.pi / 180.0)) *
          math.cos(lat2 * (math.pi / 180.0)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

/// Central state controller holding real-time venue, category, GPS status,
/// and anti-flicker venue detection state.
class VenueController extends ChangeNotifier {
  final ApiService _apiService;
  final ILocationService? locationService;

  // Active venue and category state
  VenueType _currentVenueType = VenueType.hospital;
  VenueItem? _currentVenue;
  bool _isGpsDetected = true;
  bool _isOutsidePredefined = false;

  // GPS real-time status
  String _gpsStatusText = 'GPS: searching...';
  Position? _lastPosition;
  double? _lastMatchedDistanceMeters;
  String? _lastBackendResponse;
  String? _lastError;
  bool _isFollowMode = true;

  // Anti-flicker tracking
  String? _pendingDetectedSlug;
  int _consecutiveDetectedCount = 0;
  int _consecutiveOutsideCount = 0;

  // Request throttling (> 25m or >= 15s)
  Position? _lastSentPosition;
  DateTime? _lastSentTime;
  bool _isDetecting = false;
  int _backendRequestId = 0;

  // Manual override tracking
  VenueItem? _manualVenue;

  // Overlay state & deferred switch
  bool _isCardOverlayOpen = false;
  Map<String, dynamic>? _deferredAutoSwitchData;

  // Auto-switch notification & Undo support
  String? _autoSwitchNotification;
  VenueItem? _previousVenue;
  VenueType? _previousVenueType;
  bool _previousIsGpsDetected = true;

  VenueController({
    ApiService? apiService,
    this.locationService,
    VenueType initialVenueType = VenueType.hospital,
    VenueItem? initialVenue,
  })  : _apiService = apiService ?? ApiService(),
        _currentVenueType = initialVenueType,
        _currentVenue = initialVenue ?? _findDefaultVenueForType(initialVenueType);

  // --- Getters ---
  VenueType get currentVenueType => _currentVenueType;
  VenueItem? get currentVenue => _currentVenue;
  bool get isGpsDetected => _isGpsDetected;
  bool get isOutsidePredefined => _isOutsidePredefined;
  String get gpsStatusText => _gpsStatusText;
  Position? get lastPosition => _lastPosition;
  double? get lastMatchedDistanceMeters => _lastMatchedDistanceMeters;
  String? get lastBackendResponse => _lastBackendResponse;
  String? get lastError => _lastError;
  bool get isFollowMode => _isFollowMode;
  bool get isCardOverlayOpen => _isCardOverlayOpen;
  String? get autoSwitchNotification => _autoSwitchNotification;

  /// Returns communication categories corresponding to the current venue type.
  List<CommunicationCategory> get currentCategories {
    switch (_currentVenueType) {
      case VenueType.supermarket:
        return CommunicationData.supermarketCategories;
      case VenueType.hospital:
        return CommunicationData.hospitalCategories;
      case VenueType.bank:
        return CommunicationData.bankCategories;
      case VenueType.restaurant:
        return CommunicationData.restaurantCategories;
      case VenueType.other:
        return CommunicationData.hospitalCategories;
    }
  }

  /// Returns the category slug expected by SuggestApi.
  VenueCategory get suggestCategory {
    switch (_currentVenueType) {
      case VenueType.supermarket:
        return VenueCategory.supermarket;
      case VenueType.hospital:
        return VenueCategory.hospital;
      case VenueType.bank:
        return VenueCategory.bank;
      case VenueType.restaurant:
        return VenueCategory.restaurant;
      case VenueType.other:
        return VenueCategory.hospital;
    }
  }

  StreamSubscription<Position>? _positionSubscription;

  // --- Initialization ---
  Future<void> initLocation() async {
    final service = locationService;
    if (service == null) return;

    _positionSubscription?.cancel();
    _positionSubscription = service.positionStream.listen(
      onPositionUpdate,
      onError: (dynamic error) {
        _gpsStatusText = 'GPS error: $error';
        _lastError = error.toString();
        notifyListeners();
      },
    );

    final granted = await service.initAndRequestPermission();
    if (!granted) {
      _gpsStatusText = service.statusMessage;
      notifyListeners();
    }
  }

  Future<bool> openAppSettings() async => locationService?.openAppSettings() ?? false;
  Future<bool> openLocationSettings() async => locationService?.openLocationSettings() ?? false;
  Future<bool> retryPermission() async {
    final service = locationService;
    if (service == null) return false;
    final granted = await service.initAndRequestPermission();
    if (!granted) {
      _gpsStatusText = service.statusMessage;
      notifyListeners();
    }
    return granted;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  // --- Real-time Position Stream Consumer ---
  void onPositionUpdate(Position position) {
    _lastPosition = position;
    if (_currentVenue != null) {
      _lastMatchedDistanceMeters = calculateDistanceMeters(
        position.latitude,
        position.longitude,
        _currentVenue!.lat,
        _currentVenue!.lon,
      );
    }

    // Accuracy check: if worse than 100m, show Low GPS accuracy and do NOT auto-switch
    if (position.accuracy > 100) {
      _gpsStatusText = 'Low GPS accuracy (${position.accuracy.round()} m)';
      notifyListeners();
      return;
    }

    _gpsStatusText = 'GPS accuracy: ${position.accuracy.round()} m';

    // Throttle check: send to backend when moved > 25m or every 15s
    final now = DateTime.now();
    bool shouldSend = false;

    if (_lastSentPosition == null || _lastSentTime == null) {
      shouldSend = true;
    } else {
      final distance = calculateDistanceMeters(
        _lastSentPosition!.latitude,
        _lastSentPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      final elapsedSeconds = now.difference(_lastSentTime!).inSeconds;

      if (distance >= 25.0 || elapsedSeconds >= 15) {
        shouldSend = true;
      }
    }

    notifyListeners();

    if (shouldSend) {
      _sendPositionToBackend(position);
    }
  }

  Future<void> _sendPositionToBackend(Position position) async {
    if (_isDetecting) return; // Never send more than one request at a time

    _isDetecting = true;
    final requestId = ++_backendRequestId;
    _lastSentPosition = position;
    _lastSentTime = DateTime.now();

    try {
      final result = await _apiService.detectLocation(
        position.latitude,
        position.longitude,
      );

      // Ignore out-of-order responses
      if (requestId != _backendRequestId) return;

      _lastBackendResponse = result.toString();
      _processDetectionResult(result, position);
    } catch (e) {
      if (requestId == _backendRequestId) {
        _lastError = 'Backend detection error: $e';
        notifyListeners();
      }
    } finally {
      _isDetecting = false;
    }
  }

  void _processDetectionResult(Map<String, dynamic> result, Position position) {
    final bool isPredefined = result['is_predefined'] == true;
    final String slug = (result['detected_slug'] ?? 'other').toString().toLowerCase();

    // Map slug to exactly one of: hospital, bank, restaurant, supermarket
    final VenueType? matchedType = _mapSlugToVenueType(slug);

    if (isPredefined && matchedType != null) {
      _consecutiveOutsideCount = 0;

      if (_pendingDetectedSlug == slug) {
        _consecutiveDetectedCount++;
      } else {
        _pendingDetectedSlug = slug;
        _consecutiveDetectedCount = 1;
      }

      // Avoid flicker: switch only after two consecutive fixes agree
      if (_consecutiveDetectedCount >= 2) {
        final venueItem = _resolveVenueItem(result, matchedType, position);

        // Check if manual choice wins:
        // Manual choice stays until user taps "Use GPS again" or GPS places them
        // at a different venue after they have moved away (> 800m from manual venue).
        if (!_isGpsDetected && _manualVenue != null) {
          final distToManual = calculateDistanceMeters(
            position.latitude,
            position.longitude,
            _manualVenue!.lat,
            _manualVenue!.lon,
          );

          if (venueItem != null && venueItem.id != _manualVenue!.id && distToManual > 800) {
            // Moved away to a different venue: GPS auto-switch takes over
            _applyOrDeferVenueSwitch(matchedType, venueItem, isGps: true);
          }
        } else {
          // GPS detection active
          _applyOrDeferVenueSwitch(matchedType, venueItem, isGps: true);
        }
      }
    } else {
      // Outside predefined venues
      _consecutiveDetectedCount = 0;
      _consecutiveOutsideCount++;

      // Leave venue only after two consecutive fixes put user clearly outside
      if (_consecutiveOutsideCount >= 2) {
        if (_isGpsDetected) {
          _isOutsidePredefined = true;
          _lastMatchedDistanceMeters = null;
          // Do NOT guess a category; keep whatever current category was or allow user to pick
          notifyListeners();
        }
      }
    }
  }

  void _applyOrDeferVenueSwitch(VenueType type, VenueItem? venue, {required bool isGps}) {
    if (_isCardOverlayOpen) {
      // Defer switch until overlay closes
      _deferredAutoSwitchData = {
        'type': type,
        'venue': venue,
        'isGps': isGps,
      };
      return;
    }

    _applyVenueSwitch(type, venue, isGps: isGps);
  }

  void _applyVenueSwitch(VenueType type, VenueItem? venue, {required bool isGps}) {
    if (_currentVenueType == type && _currentVenue?.id == venue?.id && _isGpsDetected == isGps) {
      return;
    }

    // Save previous for Undo
    _previousVenue = _currentVenue;
    _previousVenueType = _currentVenueType;
    _previousIsGpsDetected = _isGpsDetected;

    _currentVenueType = type;
    _currentVenue = venue ?? _findDefaultVenueForType(type);
    _isGpsDetected = isGps;
    _isOutsidePredefined = false;

    if (venue != null && _lastPosition != null) {
      _lastMatchedDistanceMeters = calculateDistanceMeters(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        venue.lat,
        venue.lon,
      );
    }

    if (isGps) {
      _manualVenue = null;
      final venueName = venue?.name ?? type.displayNameEn;
      _autoSwitchNotification = 'Detected: $venueName - ${type.displayNameEn}';
    }

    notifyListeners();
  }

  // --- Manual Selection Handlers ---

  /// Manual choice when user taps a venue pin on the map.
  void selectManualVenue(VenueItem venue) {
    _manualVenue = venue;
    _applyVenueSwitch(venue.type, venue, isGps: false);
  }

  /// Manual choice when user chooses category from picker (e.g. outside predefined venues).
  void selectManualCategory(VenueType type) {
    final venue = _findDefaultVenueForType(type);
    _manualVenue = venue;
    _applyVenueSwitch(type, venue, isGps: false);
  }

  /// User taps "Use GPS again" to restore GPS following mode.
  Future<void> useGpsAgain() async {
    _manualVenue = null;
    _isGpsDetected = true;
    _isFollowMode = true;
    _consecutiveDetectedCount = 0;
    _consecutiveOutsideCount = 0;
    _lastSentPosition = null;
    _lastSentTime = null;

    if (_lastPosition != null) {
      await _sendPositionToBackend(_lastPosition!);
    } else {
      notifyListeners();
    }
  }

  /// Undo the last automatic switch.
  void undoAutoSwitch() {
    if (_previousVenueType != null) {
      _currentVenueType = _previousVenueType!;
      _currentVenue = _previousVenue;
      _isGpsDetected = _previousIsGpsDetected;
      _manualVenue = _isGpsDetected ? null : _currentVenue;
      _autoSwitchNotification = null;
      notifyListeners();
    }
  }

  void dismissNotification() {
    _autoSwitchNotification = null;
    notifyListeners();
  }

  void setFollowMode(bool follow) {
    if (_isFollowMode != follow) {
      _isFollowMode = follow;
      notifyListeners();
    }
  }

  void setCardOverlayOpen(bool open) {
    _isCardOverlayOpen = open;
    if (!open && _deferredAutoSwitchData != null) {
      final data = _deferredAutoSwitchData!;
      _deferredAutoSwitchData = null;
      _applyVenueSwitch(
        data['type'] as VenueType,
        data['venue'] as VenueItem?,
        isGps: data['isGps'] as bool,
      );
    }
  }

  // --- Helper Methods ---

  static VenueType? _mapSlugToVenueType(String slug) {
    switch (slug) {
      case 'hospital':
        return VenueType.hospital;
      case 'bank':
        return VenueType.bank;
      case 'restaurant':
        return VenueType.restaurant;
      case 'supermarket':
        return VenueType.supermarket;
      default:
        return null;
    }
  }

  VenueItem? _resolveVenueItem(
    Map<String, dynamic> result,
    VenueType type,
    Position position,
  ) {
    final poiName = (result['poi_name'] ?? '').toString();
    final allVenues = [
      ...VenueData.hospitals,
      ...VenueData.banks,
      ...VenueData.restaurants,
      ...VenueData.supermarkets,
    ];

    // Try finding by name match
    if (poiName.isNotEmpty) {
      final nameLower = poiName.toLowerCase();
      for (final v in allVenues) {
        if (v.type == type &&
            (v.name.toLowerCase() == nameLower ||
                v.shortName.toLowerCase() == nameLower ||
                nameLower.contains(v.shortName.toLowerCase()))) {
          return v;
        }
      }
    }

    // Try finding closest known venue of that type
    VenueItem? closest;
    double minDistance = double.infinity;

    for (final v in allVenues.where((v) => v.type == type)) {
      final d = calculateDistanceMeters(position.latitude, position.longitude, v.lat, v.lon);
      if (d < minDistance) {
        minDistance = d;
        closest = v;
      }
    }

    return closest ?? _findDefaultVenueForType(type);
  }

  static VenueItem? _findDefaultVenueForType(VenueType type) {
    switch (type) {
      case VenueType.supermarket:
        return VenueData.supermarkets.isNotEmpty ? VenueData.supermarkets.first : null;
      case VenueType.hospital:
        return VenueData.hospitals.isNotEmpty ? VenueData.hospitals.first : null;
      case VenueType.bank:
        return VenueData.banks.isNotEmpty ? VenueData.banks.first : null;
      case VenueType.restaurant:
        return VenueData.restaurants.isNotEmpty ? VenueData.restaurants.first : null;
      case VenueType.other:
        return null;
    }
  }
}
