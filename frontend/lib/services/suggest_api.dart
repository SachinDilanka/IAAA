import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Venue categories. The API values must match the backend exactly.
enum VenueCategory {
  hospital('hospital'),
  bank('bank'),
  restaurant('restaurant'),
  supermarket('supermarket');

  const VenueCategory(this.apiValue);
  final String apiValue;
}

class Phrase {
  const Phrase({required this.english, required this.sinhala, this.score});

  final String english;
  final String sinhala;
  final double? score; // only for ordering; never show it to users as a "percentage"

  factory Phrase.fromJson(Map<String, dynamic> j) => Phrase(
        english: (j['english'] ?? '') as String,
        sinhala: (j['sinhala'] ?? '') as String,
        score: (j['score'] as num?)?.toDouble(),
      );
}

class SuggestResult {
  const SuggestResult({
    required this.pinned,
    required this.results,
    required this.lowConfidence,
  });

  final List<Phrase> pinned;
  final List<Phrase> results;
  final bool lowConfidence;

  factory SuggestResult.fromJson(Map<String, dynamic> j) => SuggestResult(
        pinned: ((j['pinned'] ?? []) as List)
            .map((e) => Phrase.fromJson(e as Map<String, dynamic>))
            .toList(),
        results: ((j['results'] ?? []) as List)
            .map((e) => Phrase.fromJson(e as Map<String, dynamic>))
            .toList(),
        lowConfidence: (j['low_confidence'] ?? false) as bool,
      );
}

class SuggestException implements Exception {
  SuggestException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SuggestApi {
  SuggestApi({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  /// e.g. 'http://10.0.2.2:8000' (Android emulator) or 'http://192.168.1.20:8000'
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  Future<SuggestResult> suggest({
    required VenueCategory category,
    required String query,
    int topK = 5,
  }) async {
    final uri = Uri.parse('$baseUrl/suggest');
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'category': category.apiValue,
              'query': query, // sent exactly as typed
              'top_k': topK,
            }),
          )
          .timeout(timeout);

      if (res.statusCode != 200) {
        throw SuggestException('Server error (${res.statusCode}).');
      }
      // Decode as UTF-8 explicitly so Sinhala text is never garbled.
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return SuggestResult.fromJson(data);
    } on TimeoutException {
      throw SuggestException('The server took too long to respond.');
    } on http.ClientException {
      throw SuggestException('Cannot reach the server. Check your connection.');
    } on FormatException {
      throw SuggestException('Unexpected reply from the server.');
    }
  }

  void dispose() => _client.close();
}
