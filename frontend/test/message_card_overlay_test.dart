import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/models/communication_models.dart';
import 'package:frontend/screens/category_detail_screen.dart';
import 'package:frontend/services/suggest_api.dart';
import 'package:frontend/widgets/message_card_overlay.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessageCardOverlay Tests', () {
    // -------------------------------------------------------------
    // Test 1: Select message in long scrolled list & scroll offset unchanged
    // -------------------------------------------------------------
    testWidgets('(1) select message in long scrolled list: overlay appears and scroll offset is unchanged',
        (WidgetTester tester) async {
      // Build a category with 30 messages to ensure a long scrollable list
      final messages = List.generate(
        30,
        (i) => CommunicationMessage(
          id: i + 1,
          category: 'Test Category',
          templateSi: 'සිංහල පණිවිඩය අංක ${i + 1}',
          templateEn: 'English message number ${i + 1}',
        ),
      );

      final category = CommunicationCategory(
        id: 'test_cat',
        key: 'test_cat',
        name: 'Test Category',
        nameEn: 'Test Category',
        nameSi: 'පරීක්ෂණ කාණ්ඩය',
        icon: Icons.local_hospital,
        count: messages.length,
        messages: messages,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CategoryDetailScreen(
            category: category,
            venueType: VenueType.hospital,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable).first;
      final scrollableState = tester.state<ScrollableState>(scrollableFinder);
      final initialOffset = scrollableState.position.pixels;
      expect(initialOffset, 0.0);

      // Scroll down substantially
      await tester.drag(scrollableFinder, const Offset(0, -600));
      await tester.pumpAndSettle();

      final scrolledOffset = scrollableState.position.pixels;
      expect(scrolledOffset, greaterThan(200.0));

      // Select a message that is now in view
      final targetMessageFinder = find.text('සිංහල පණිවිඩය අංක 8');
      expect(targetMessageFinder, findsOneWidget);

      await tester.tap(targetMessageFinder);
      await tester.pumpAndSettle();

      // Verify the overlay appears
      expect(find.byType(MessageCardOverlay), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MessageCardOverlay),
          matching: find.text('සිංහල පණිවිඩය අංක 8'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(MessageCardOverlay),
          matching: find.text('English message number 8'),
        ),
        findsOneWidget,
      );

      // Verify the background list's scroll offset is completely unchanged
      expect(scrollableState.position.pixels, scrolledOffset);

      // Close the overlay using Close button
      await tester.tap(find.byKey(const Key('message_card_close_button')));
      await tester.pumpAndSettle();

      // Verify overlay dismissed and list offset still identical
      expect(find.byType(MessageCardOverlay), findsNothing);
      expect(scrollableState.position.pixels, scrolledOffset);
    });

    // -------------------------------------------------------------
    // Test 2: Close and back dismiss the overlay
    // -------------------------------------------------------------
    testWidgets('(2) Close button and back dismiss the overlay', (WidgetTester tester) async {
      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                testContext = ctx;
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showMessageCard(
                        ctx,
                        sinhala: 'මට උදව් අවශ්‍යයි.',
                        english: 'I need help.',
                        categoryName: 'General',
                        id: 1,
                      );
                    },
                    child: const Text('Open Card'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // --- Part A: Dismiss via Close (X) button ---
      await tester.tap(find.text('Open Card'));
      await tester.pumpAndSettle();

      expect(find.byType(MessageCardOverlay), findsOneWidget);

      await tester.tap(find.byKey(const Key('message_card_close_button')));
      await tester.pumpAndSettle();

      expect(find.byType(MessageCardOverlay), findsNothing);

      // --- Part B: Dismiss via Bottom Dismiss button ---
      await tester.tap(find.text('Open Card'));
      await tester.pumpAndSettle();

      expect(find.byType(MessageCardOverlay), findsOneWidget);

      await tester.tap(find.byKey(const Key('message_card_dismiss_button')));
      await tester.pumpAndSettle();

      expect(find.byType(MessageCardOverlay), findsNothing);

      // --- Part C: Dismiss via Back navigation / pop ---
      await tester.tap(find.text('Open Card'));
      await tester.pumpAndSettle();

      expect(find.byType(MessageCardOverlay), findsOneWidget);

      // Simulate back dismissal through Navigator pop
      Navigator.of(testContext, rootNavigator: true).pop();
      await tester.pumpAndSettle();

      expect(find.byType(MessageCardOverlay), findsNothing);
    });

    // -------------------------------------------------------------
    // Test 3: Suggestion panel phrase tap and "Use my own words"
    // -------------------------------------------------------------
    testWidgets('(3) suggestion panel phrase tap and "Use my own words" both open the same overlay',
        (WidgetTester tester) async {
      final mockClient = MockHttpClient((req) async {
        return http.Response(
          '''{
            "pinned": [
              {"english": "I am deaf.", "sinhala": "මම බිහිරි කෙනෙක්."}
            ],
            "results": [
              {"english": "Where is the pharmacy?", "sinhala": "ඖෂධාගාරය කොහේද?", "score": 0.95}
            ],
            "low_confidence": false
          }''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final suggestApi = SuggestApi(
        baseUrl: 'http://127.0.0.1:5000',
        client: mockClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => SuggestionPanel(
                api: suggestApi,
                category: VenueCategory.hospital,
                onPhraseSelected: (phrase) {
                  showMessageCard(
                    ctx,
                    sinhala: phrase.sinhala,
                    english: phrase.english,
                    categoryName: 'Hospital Suggestions',
                  );
                },
                onTypedTextSelected: (typedText) {
                  showMessageCard(
                    ctx,
                    sinhala: typedText,
                    english: '',
                    categoryName: 'Custom Words',
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Case A: Tapping a pinned/suggested phrase opens MessageCardOverlay
      final phraseTile = find.text('I am deaf.');
      expect(phraseTile, findsOneWidget);

      await tester.tap(phraseTile);
      await tester.pumpAndSettle();

      expect(find.byType(MessageCardOverlay), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MessageCardOverlay),
          matching: find.text('මම බිහිරි කෙනෙක්.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(MessageCardOverlay),
          matching: find.text('I am deaf.'),
        ),
        findsOneWidget,
      );

      // Close overlay
      await tester.tap(find.byKey(const Key('message_card_close_button')));
      await tester.pumpAndSettle();
      expect(find.byType(MessageCardOverlay), findsNothing);

      // Case B: Typing custom text and tapping "Use my own words" opens the same MessageCardOverlay
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'මට වතුර ටිකක් බොන්න ඕනේ');
      await tester.pumpAndSettle();

      final useMyWordsBtn = find.text('Use my own words');
      expect(useMyWordsBtn, findsOneWidget);

      await tester.tap(useMyWordsBtn);
      await tester.pumpAndSettle();

      expect(find.byType(MessageCardOverlay), findsOneWidget);
      expect(find.text('මට වතුර ටිකක් බොන්න ඕනේ'), findsWidgets);
      expect(find.text('Custom Words'), findsOneWidget);

      // Close overlay
      await tester.tap(find.byKey(const Key('message_card_close_button')));
      await tester.pumpAndSettle();
      expect(find.byType(MessageCardOverlay), findsNothing);

      suggestApi.dispose();
    });

    // -------------------------------------------------------------
    // Test 4: Very long text does not overflow
    // -------------------------------------------------------------
    testWidgets('(4) very long text does not overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const veryLongSinhala =
          'මෙය ඉතා දිගු සිංහල පණිවිඩයකි. මෙම පණිවිඩය මඟින් රෝහල් කාර්ය මණ්ඩලයට හෝ සුපිරි වෙළඳසැලේ සේවකයන්ට අවශ්‍ය සියලුම සවිස්තරාත්මක තොරතුරු පැහැදිලිව ඉදිරිපත් කරයි. '
          'මට වෛද්‍යවරයා හමුවීමට අවශ්‍ය අතර මට පපුවේ තද කැක්කුමක් සහ හුස්ම ගැනීමේ අපහසුතාවයක් පවතී. කරුණාකර මට වහාම හදිසි ප්‍රතිකාර ඒකකයට මඟ පෙන්වන්න. '
          'මම බිහිරි අයෙකු බැවින් කරුණාකර මට ලියා හෝ අභිනයෙන් දන්වන්න. ස්තූතියි!';

      const veryLongEnglish =
          'This is an extremely long test message designed to verify that the message card overlay does not overflow '
          'even when displaying extensive descriptions. I need to see the emergency doctor immediately due to severe chest pain '
          'and shortness of breath. Please guide me directly to the emergency triage room. As I am deaf, kindly write down instructions '
          'or communicate using clear gestures. Thank you for your assistance!';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showMessageCard(
                      ctx,
                      sinhala: veryLongSinhala,
                      english: veryLongEnglish,
                      categoryName: 'Emergency Long Note',
                      id: 99,
                    );
                  },
                  child: const Text('Show Long Card'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show Long Card'));
      await tester.pumpAndSettle();

      expect(find.byType(MessageCardOverlay), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify that all font sizes (S, M, L, XL) can be selected without overflowing
      for (final label in ['S', 'M', 'L', 'XL']) {
        final chip = find.text(label);
        expect(chip, findsOneWidget);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      // Verify Copy button functions without errors
      final copyBtn = find.byKey(const Key('message_card_copy_button'));
      expect(copyBtn, findsOneWidget);
      await tester.tap(copyBtn);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);

      // Verify 180° flip button works without errors
      final flipBtn = find.text('180°');
      expect(flipBtn, findsOneWidget);
      await tester.tap(flipBtn);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Close overlay
      await tester.tap(find.byKey(const Key('message_card_close_button')));
      await tester.pumpAndSettle();
      expect(find.byType(MessageCardOverlay), findsNothing);
    });
  });
}
