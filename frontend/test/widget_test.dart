import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/data/communication_data.dart';

void main() {
  testWidgets('CommAssistApp renders first interface from mockup with hospital and supermarket categories', (WidgetTester tester) async {
    await tester.pumpWidget(const CommAssistApp());
    await tester.pumpAndSettle();

    // Verify app titles
    expect(find.text('AI Communication Assistant'), findsOneWidget);
    expect(find.text('CommAssist Sri Lanka'), findsOneWidget);

    // Verify Hospital first interface from mockup
    expect(find.text('CURRENT LOCATION'), findsOneWidget);
    expect(find.text('Select a Message'), findsOneWidget);
    expect(find.text('I have an appointment'), findsOneWidget);
    expect(find.text('Custom Typing'), findsOneWidget);

    // Verify Supermarket chip is available and selectable
    final smChip = find.text('Supermarket (9 Cat.)');
    expect(smChip, findsOneWidget);

    // Switch to Categories tab to verify supermarket categories
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    // Switch to Supermarket in categories
    await tester.tap(find.text('Supermarket (9 Cat.)'));
    await tester.pumpAndSettle();

    // Verify Supermarket categories count (9 categories)
    expect(CommunicationData.supermarketCategories.length, 9);
    expect(find.text('මූලික සන්නිවේදනය'), findsOneWidget);
    expect(find.text('Basic communication'), findsOneWidget);
  });
}
