import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../data/communication_data.dart';
import '../data/venue_data.dart';

class ApiService {
  final String baseUrl;
  final http.Client? client;

  ApiService({this.baseUrl = AppConfig.backendBaseUrl, this.client});

  /// Detects venue location given latitude and longitude.
  /// Falls back to local nearest venue calculation if the server is unreachable.
  Future<Map<String, dynamic>> detectLocation(double lat, double lon) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .post(
            Uri.parse('$baseUrl/api/detect-location'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'lat': lat, 'lon': lon}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Backend API unreachable, using local location fallback: $e');
      }
    }

    // Local fallback: find closest venue among pre-seeded list within ~0.8km
    return _localProximityDetection(lat, lon);
  }

  Map<String, dynamic> _localProximityDetection(double lat, double lon) {
    // Check supermarkets
    for (final sm in VenueData.supermarkets) {
      if ((sm.lat - lat).abs() < 0.008 && (sm.lon - lon).abs() < 0.008) {
        return {
          'success': true,
          'detected_slug': 'supermarket',
          'is_supermarket': true,
          'is_predefined': true,
          'poi_name': sm.name,
          'venue_info': sm,
          'categories': CommunicationData.supermarketCategories,
        };
      }
    }

    // Check hospitals
    for (final h in VenueData.hospitals) {
      if ((h.lat - lat).abs() < 0.008 && (h.lon - lon).abs() < 0.008) {
        return {
          'success': true,
          'detected_slug': 'hospital',
          'is_hospital': true,
          'is_predefined': true,
          'poi_name': h.name,
          'venue_info': h,
          'categories': CommunicationData.hospitalCategories,
        };
      }
    }

    // Check banks
    for (final b in VenueData.banks) {
      if ((b.lat - lat).abs() < 0.008 && (b.lon - lon).abs() < 0.008) {
        return {
          'success': true,
          'detected_slug': 'bank',
          'is_bank': true,
          'is_predefined': true,
          'poi_name': b.name,
          'venue_info': b,
          'categories': CommunicationData.bankCategories,
        };
      }
    }

    // Check restaurants
    for (final r in VenueData.restaurants) {
      if ((r.lat - lat).abs() < 0.008 && (r.lon - lon).abs() < 0.008) {
        return {
          'success': true,
          'detected_slug': 'restaurant',
          'is_restaurant': true,
          'is_predefined': true,
          'poi_name': r.name,
          'venue_info': r,
          'categories': CommunicationData.restaurantCategories,
        };
      }
    }

    // Outside every predefined venue: do NOT guess a category
    return {
      'success': true,
      'detected_slug': 'other',
      'is_predefined': false,
      'poi_name': 'Outside Predefined Venues',
      'location_name': 'Outside predefined venues',
    };
  }
}
