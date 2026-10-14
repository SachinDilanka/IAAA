import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/communication_data.dart';
import '../data/venue_data.dart';

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'http://127.0.0.1:5000'});

  /// Detects venue location given latitude and longitude.
  /// Falls back to local nearest venue calculation if the server is unreachable.
  Future<Map<String, dynamic>> detectLocation(double lat, double lon) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/detect-location'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'lat': lat, 'lon': lon}),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Backend API unreachable, using local location fallback: $e');
      }
    }

    // Local fallback: find closest venue among pre-seeded list
    return _localProximityDetection(lat, lon);
  }

  Map<String, dynamic> _localProximityDetection(double lat, double lon) {
    // Check supermarkets
    for (final sm in VenueData.supermarkets) {
      if ((sm.lat - lat).abs() < 0.015 && (sm.lon - lon).abs() < 0.015) {
        return {
          'success': true,
          'detected_slug': 'supermarket',
          'is_supermarket': true,
          'poi_name': sm.name,
          'venue_info': sm,
          'categories': CommunicationData.supermarketCategories,
        };
      }
    }

    // Check hospitals
    for (final h in VenueData.hospitals) {
      if ((h.lat - lat).abs() < 0.015 && (h.lon - lon).abs() < 0.015) {
        return {
          'success': true,
          'detected_slug': 'hospital',
          'is_hospital': true,
          'poi_name': h.name,
          'venue_info': h,
          'categories': CommunicationData.hospitalCategories,
        };
      }
    }

    // Default to supermarket as active venue
    final fallbackSm = VenueData.supermarkets.first;
    return {
      'success': true,
      'detected_slug': 'supermarket',
      'is_supermarket': true,
      'poi_name': fallbackSm.name,
      'venue_info': fallbackSm,
      'categories': CommunicationData.supermarketCategories,
    };
  }
}
