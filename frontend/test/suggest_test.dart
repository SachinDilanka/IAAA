import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/services/suggest_api.dart';
import 'package:frontend/widgets/suggestion_panel.dart';

class MockHttpClient extends http.BaseClient {
  MockHttpClient(this._handler);

  final Future<http.Response> Function(http.Request request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final response = await _handler(httpRequest);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  group('SuggestApi Unit Tests', () {
    test('successful response parses pinned and results with UTF-8 Sinhala', () async {
      final mockClient = MockHttpClient((req) async {
        expect(req.url.path, '/api/suggest');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['category'], 'supermarket');
        expect(body['query'], 'rice');

        final payload = {
          'pinned': [
            {'english': 'I am deaf.', 'sinhala': 'මම බිහිරි කෙනෙක්.'},
          ],
          'results': [
            {'english': 'Where is the rice?', 'sinhala': 'සහල් කොහෙද?', 'score': 0.95},
          ],
          'low_confidence': false,
        };
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final api = SuggestApi(
        baseUrl: 'http://127.0.0.1:5000/api',
        client: mockClient,
      );

      final res = await api.suggest(
        category: VenueCategory.supermarket,
        query: 'rice',
      );

      expect(res.pinned.length, 1);
      expect(res.pinned.first.english, 'I am deaf.');
      expect(res.pinned.first.sinhala, 'මම බිහිරි කෙනෙක්.');
      expect(res.results.length, 1);
      expect(res.results.first.english, 'Where is the rice?');
      expect(res.results.first.sinhala, 'සහල් කොහෙද?');
      expect(res.lowConfidence, isFalse);

      api.dispose();
    });

    test('server error 503 throws SuggestException', () async {
      final mockClient = MockHttpClient((req) async {
        return http.Response('{"error": "ML service unavailable"}', 503);
      });

      final api = SuggestApi(
        baseUrl: 'http://127.0.0.1:5000/api',
        client: mockClient,
      );

      expect(
        () => api.suggest(category: VenueCategory.hospital, query: 'fever'),
        throwsA(isA<SuggestException>()),
      );

      api.dispose();
    });
  });

  group('SuggestionPanel Widget Tests', () {
    testWidgets('renders pinned quick phrases and responds to phrase tap', (tester) async {
      final mockClient = MockHttpClient((req) async {
        final payload = {
          'pinned': [
            {'english': 'I am deaf.', 'sinhala': 'මම බිහිරි කෙනෙක්.'},
          ],
          'results': [
            {'english': 'Where is the rice?', 'sinhala': 'සහල් කොහෙද?', 'score': 0.95},
          ],
          'low_confidence': false,
        };
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final api = SuggestApi(
        baseUrl: 'http://127.0.0.1:5000/api',
        client: mockClient,
      );

      Phrase? selectedPhrase;
      String? typedTextSelected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 500,
              child: SuggestionPanel(
                api: api,
                category: VenueCategory.supermarket,
                onPhraseSelected: (p) => selectedPhrase = p,
                onTypedTextSelected: (t) => typedTextSelected = t,
              ),
            ),
          ),
        ),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      // Pinned phrase is displayed
      expect(find.text('Quick phrases'), findsOneWidget);
      expect(find.text('මම බිහිරි කෙනෙක්.'), findsOneWidget);
      expect(find.text('I am deaf.'), findsOneWidget);

      // Suggestion phrase is displayed
      expect(find.text('සහල් කොහෙද?'), findsOneWidget);
      expect(find.text('Where is the rice?'), findsOneWidget);

      // Tap on the pinned phrase
      await tester.tap(find.text('මම බිහිරි කෙනෙක්.'));
      expect(selectedPhrase, isNotNull);
      expect(selectedPhrase?.english, 'I am deaf.');

      // Test typing text and "Use my own words"
      await tester.enterText(find.byType(TextField), 'I need assistance');
      await tester.pump();

      expect(find.text('Use my own words'), findsOneWidget);
      await tester.tap(find.text('Use my own words'));
      expect(typedTextSelected, 'I need assistance');

      api.dispose();
    });

    testWidgets('displays error gracefully when service is unavailable', (tester) async {
      final mockClient = MockHttpClient((req) async {
        return http.Response('{"error": "Unavailable"}', 503);
      });

      final api = SuggestApi(
        baseUrl: 'http://127.0.0.1:5000/api',
        client: mockClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 500,
              child: SuggestionPanel(
                api: api,
                category: VenueCategory.hospital,
                onPhraseSelected: (_) {},
                onTypedTextSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Error message and retry button are shown without crashing
      expect(find.text('Server error (503).'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      api.dispose();
    });
  });
}
