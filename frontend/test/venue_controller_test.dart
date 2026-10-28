import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/controllers/venue_controller.dart';
import 'package:frontend/data/communication_data.dart';
import 'package:frontend/data/venue_data.dart';
import 'package:frontend/models/communication_models.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/location_service.dart';
import 'package:frontend/services/suggest_api.dart';

Position createTestPosition({
  required double latitude,
  required double longitude,
  double accuracy = 10.0,
  double speed = 0.0,
  DateTime? timestamp,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: accuracy,
    altitude: 0.0,
    heading: 0.0,
    speed: speed,
    speedAccuracy: 0.0,
    altitudeAccuracy: 0.0,
    headingAccuracy: 0.0,
  );
}

class MockLocationService implements ILocationService {
  final StreamController<Position> _controller = StreamController<Position>.broadcast();
  LocationServiceStatus _status = LocationServiceStatus.searching;
  String _statusMessage = 'GPS: searching...';
  bool permissionGranted = true;
  bool paused = false;

  @override
  Stream<Position> get positionStream => _controller.stream;

  @override
  LocationServiceStatus get status => _status;

  @override
  String get statusMessage => _statusMessage;

  void emitPosition(Position pos) {
    _controller.add(pos);
  }

  void setDenied(bool forever) {
    permissionGranted = false;
    _status = forever ? LocationServiceStatus.permissionDeniedForever : LocationServiceStatus.permissionDenied;
    _statusMessage = forever
        ? 'Location permission is permanently denied. Please enable in App Settings.'
        : 'Location permission denied. Real-time venue detection is unavailable.';
  }

  @override
  Future<bool> initAndRequestPermission() async {
    return permissionGranted;
  }

  @override
  void pause() {
    paused = true;
  }

  @override
  void resume() {
    paused = false;
  }

  @override
  void dispose() {
    _controller.close();
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  group('Real-time Location & Venue Auto-Switch Tests', () {
    late MockLocationService mockLocation;
    late http.Client mockHttpClient;
    late ApiService apiService;

    setUp(() {
      mockLocation = MockLocationService();
      mockHttpClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final double lat = (body['lat'] as num).toDouble();
        final double lon = (body['lon'] as num).toDouble();

        // Restaurant coordinates: Ministry of Crab (~135m from BOC Fort)
        if ((lat - 6.9332).abs() < 0.0006 && (lon - 79.8434).abs() < 0.0006) {
          return http.Response(
            jsonEncode({
              'success': true,
              'is_predefined': true,
              'detected_slug': 'restaurant',
              'is_restaurant': true,
              'poi_name': 'Ministry of Crab',
              'address': 'Old Colombo Dutch Hospital, Fort, Colombo 01',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Bank coordinates: Colombo Fort Bank
        if ((lat - 6.9344).abs() < 0.0006 && (lon - 79.8436).abs() < 0.0006) {
          return http.Response(
            jsonEncode({
              'success': true,
              'is_predefined': true,
              'detected_slug': 'bank',
              'is_bank': true,
              'poi_name': 'Bank of Ceylon (BOC) - Colombo Fort',
              'address': 'Bank of Ceylon Mawatha, Colombo 01',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Hospital coordinates
        if ((lat - 6.9192).abs() < 0.005 && (lon - 79.8681).abs() < 0.005) {
          return http.Response(
            jsonEncode({
              'success': true,
              'is_predefined': true,
              'detected_slug': 'hospital',
              'is_hospital': true,
              'poi_name': 'National Hospital of Sri Lanka (NHSL)',
              'address': 'Regent Street, Colombo 10',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Otherwise: clearly outside any predefined venue
        return http.Response(
          jsonEncode({
            'success': true,
            'is_predefined': false,
            'detected_slug': 'other',
            'poi_name': 'Outside Predefined Venues',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      apiService = ApiService(client: mockHttpClient);
    });

    tearDown(() {
      mockLocation.dispose();
      mockHttpClient.close();
    });

    test('(1) A fix inside a bank switches the category to bank and messages/suggestion follow', () async {
      final controller = VenueController(
        apiService: apiService,
        locationService: mockLocation,
        initialVenueType: VenueType.hospital,
      );
      await controller.initLocation();

      expect(controller.currentVenueType, VenueType.hospital);
      expect(controller.suggestCategory, VenueCategory.hospital);

      // Fix 1 inside Bank of Ceylon Fort
      final pos1 = createTestPosition(latitude: 6.9344, longitude: 79.8436, accuracy: 12.0);
      mockLocation.emitPosition(pos1);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // After 1 fix: anti-flicker requires 2 consecutive fixes
      expect(controller.currentVenueType, VenueType.hospital);

      // Fix 2 inside Bank of Ceylon Fort (consecutive fix #2, moved > 25m within bank)
      final pos2 = createTestPosition(latitude: 6.9348, longitude: 79.8436, accuracy: 14.0);
      mockLocation.emitPosition(pos2);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Now category switches to bank!
      expect(controller.currentVenueType, VenueType.bank);
      expect(controller.suggestCategory, VenueCategory.bank);
      expect(controller.currentCategories, CommunicationData.bankCategories);
      expect(controller.currentVenue?.type, VenueType.bank);
      expect(controller.isGpsDetected, isTrue);
      expect(controller.autoSwitchNotification, contains('Bank'));

      controller.dispose();
    });

    test('(2) A low-accuracy fix does not switch', () async {
      final controller = VenueController(
        apiService: apiService,
        locationService: mockLocation,
        initialVenueType: VenueType.hospital,
      );
      await controller.initLocation();

      expect(controller.currentVenueType, VenueType.hospital);

      // Low accuracy fix (> 100 metres, e.g. 150m) at bank coords
      final posLow = createTestPosition(latitude: 6.9344, longitude: 79.8436, accuracy: 150.0);
      mockLocation.emitPosition(posLow);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Does NOT switch venues
      expect(controller.currentVenueType, VenueType.hospital);
      expect(controller.gpsStatusText, contains('Low GPS accuracy'));

      controller.dispose();
    });

    test('(3) A single stray fix does not flip the venue', () async {
      final controller = VenueController(
        apiService: apiService,
        locationService: mockLocation,
        initialVenueType: VenueType.hospital,
      );
      await controller.initLocation();

      expect(controller.currentVenueType, VenueType.hospital);

      // Stray fix 1 at Bank coords
      final strayPos = createTestPosition(latitude: 6.9344, longitude: 79.8436, accuracy: 15.0);
      mockLocation.emitPosition(strayPos);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Single fix does NOT switch venue (anti-flicker requirement)
      expect(controller.currentVenueType, VenueType.hospital);

      // Fix 2 is back at Hospital
      final hospitalPos = createTestPosition(latitude: 6.9192, longitude: 79.8681, accuracy: 15.0);
      mockLocation.emitPosition(hospitalPos);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Remains stably at Hospital
      expect(controller.currentVenueType, VenueType.hospital);
      expect(controller.suggestCategory, VenueCategory.hospital);

      controller.dispose();
    });

    test('(4) Outside every venue shows outside status and does not guess category', () async {
      final controller = VenueController(
        apiService: apiService,
        locationService: mockLocation,
        initialVenueType: VenueType.hospital,
      );
      await controller.initLocation();

      // Coordinates out in the middle of nowhere / rural road
      final posOut1 = createTestPosition(latitude: 7.5000, longitude: 80.5000, accuracy: 15.0);
      mockLocation.emitPosition(posOut1);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final posOut2 = createTestPosition(latitude: 7.5010, longitude: 80.5010, accuracy: 15.0);
      mockLocation.emitPosition(posOut2);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Two consecutive fixes clearly outside
      expect(controller.isOutsidePredefined, isTrue);
      // Category is NOT guessed; keeps initial or lets user choose
      expect(controller.currentVenueType, VenueType.hospital);

      // User manually chooses Supermarket from category picker
      controller.selectManualCategory(VenueType.supermarket);
      expect(controller.currentVenueType, VenueType.supermarket);
      expect(controller.isOutsidePredefined, isFalse);
      expect(controller.isGpsDetected, isFalse);

      controller.dispose();
    });

    test('(5) A manual map selection beats GPS until "Use GPS again"', () async {
      final controller = VenueController(
        apiService: apiService,
        locationService: mockLocation,
        initialVenueType: VenueType.hospital,
      );
      await controller.initLocation();

      // User manually taps a bank venue on the map
      final bankVenue = VenueData.banks.first;
      controller.selectManualVenue(bankVenue);

      expect(controller.currentVenueType, VenueType.bank);
      expect(controller.isGpsDetected, isFalse);

      // GPS stream emits coordinates for Ministry of Crab Restaurant (~135m from Bank, < 800m)
      final posRest1 = createTestPosition(latitude: 6.9332, longitude: 79.8434, accuracy: 15.0);
      mockLocation.emitPosition(posRest1);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final posRest2 = createTestPosition(latitude: 6.9335, longitude: 79.8434, accuracy: 15.0);
      mockLocation.emitPosition(posRest2);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Manual choice beats GPS! Still bank!
      expect(controller.currentVenueType, VenueType.bank);
      expect(controller.isGpsDetected, isFalse);

      // User taps "Use GPS again"
      await controller.useGpsAgain();
      expect(controller.isGpsDetected, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Emit second fix at Restaurant (posRest1 is > 25m from posRest2) to satisfy anti-flicker (2 consecutive)
      mockLocation.emitPosition(posRest1);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Now GPS auto-switch takes effect and switches to Restaurant
      expect(controller.currentVenueType, VenueType.restaurant);
      expect(controller.suggestCategory, VenueCategory.restaurant);

      controller.dispose();
    });

    test('(6) Permission denied shows the explanation', () async {
      mockLocation.setDenied(false);

      final controller = VenueController(
        apiService: apiService,
        locationService: mockLocation,
      );

      await controller.initLocation();

      expect(controller.gpsStatusText, contains('Location permission denied'));

      controller.dispose();
    });

    testWidgets('Widget Test: HomeScreen reflects VenueController state, banners, and debug info', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = VenueController(
        apiService: apiService,
        locationService: mockLocation,
        initialVenueType: VenueType.hospital,
      );

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(controller: controller),
      ));
      await tester.pumpAndSettle();

      // Verify GPS status line is present
      expect(find.textContaining('GPS: searching...'), findsOneWidget);

      // Verify Showing Messages banner is displayed
      expect(find.byKey(const Key('showing_messages_banner')), findsOneWidget);
      expect(find.textContaining('Showing messages for:'), findsOneWidget);

      // Open location debug dialog
      await tester.tap(find.byKey(const Key('appbar_location_debug_button')));
      await tester.pumpAndSettle();

      expect(find.text('Location Debug Info'), findsOneWidget);
      expect(find.text('Latitude'), findsOneWidget);
      expect(find.text('Longitude'), findsOneWidget);
      expect(find.text('GPS Status'), findsOneWidget);

      // Close debug dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Test banner "Change" button opens Category Picker
      await tester.ensureVisible(find.byKey(const Key('banner_change_category_button')));
      await tester.tap(find.byKey(const Key('banner_change_category_button')));
      await tester.pumpAndSettle();

      expect(find.text('Choose Category'), findsOneWidget);
      expect(find.byKey(const Key('category_picker_bank')), findsOneWidget);

      // Tap Bank in category picker
      await tester.tap(find.byKey(const Key('category_picker_bank')));
      await tester.pumpAndSettle();

      // Verify screen switched to Bank!
      expect(controller.currentVenueType, VenueType.bank);
      expect(find.text('12 SL Banks'), findsOneWidget);

      // Verify "Use GPS again" button exists on map when manually selected
      expect(find.byKey(const Key('map_use_gps_again_button')), findsOneWidget);

      // Tap "Use GPS again"
      await tester.tap(find.byKey(const Key('map_use_gps_again_button')));
      await tester.pumpAndSettle();
      expect(controller.isGpsDetected, isTrue);

      controller.dispose();
    });
  });
}
