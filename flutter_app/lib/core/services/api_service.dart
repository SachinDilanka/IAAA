import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/child_profile.dart';
import '../models/emotion_result.dart';
import '../models/exercise.dart';
import '../models/progress_summary.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String get baseUrl => ApiConfig.baseUrl;

  Future<Map<String, dynamic>> healthCheck() async {
    final data = await _send(_client.get(Uri.parse('$baseUrl/api/health')));
    return data as Map<String, dynamic>;
  }

  Future<dynamic> _send(Future<http.Response> request) async {
    final response = await request.timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('HTTP ${response.statusCode}: ${response.body}');
    }
    return response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<ChildProfile> getChild(int id) async {
    final data = await _send(
      _client.get(Uri.parse('$baseUrl/api/children/$id')),
    );
    return ChildProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<ChildProfile> updateChild(int id, String name, int age) async {
    final data = await _send(
      _client.put(
        Uri.parse('$baseUrl/api/children/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'age': age}),
      ),
    );
    return ChildProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Exercise>> getExercises(ExerciseCategory category) async {
    final name = category.name;
    final data = await _send(
      _client.get(Uri.parse('$baseUrl/api/exercises?category=$name')),
    );
    return (data as List)
        .map((item) => Exercise.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> recordAttempt({
    required int childId,
    required int exerciseId,
    String emotion = 'happy',
  }) async {
    await _send(
      _client.post(
        Uri.parse('$baseUrl/api/attempts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'child_id': childId,
          'exercise_id': exerciseId,
          'status': 'completed',
          'attempts_count': 1,
          'stars_earned': 3,
          'detected_emotion': emotion,
        }),
      ),
    );
  }

  Future<ProgressSummary> getProgress(int childId) async {
    final data = await _send(
      _client.get(Uri.parse('$baseUrl/api/progress/$childId')),
    );
    return ProgressSummary.fromJson(data as Map<String, dynamic>);
  }

  Future<EmotionResult> analyzeEmotion(Uint8List imageBytes) async {
    final data = await _send(
      _client.post(
        Uri.parse('$baseUrl/api/emotion/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': base64Encode(imageBytes)}),
      ),
    );
    return EmotionResult.fromJson(data as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}
