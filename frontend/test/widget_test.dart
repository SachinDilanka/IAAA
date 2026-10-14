import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/data/communication_data.dart';

void main() {
  testWidgets('CommAssistApp renders home screen with supermarket categories', (WidgetTester tester) async {
    await tester.pumpWidget(const CommAssistApp());
    await tester.pumpAndSettle();

    // Verify app title
    expect(find.text('CommAssist Sri Lanka'), findsOneWidget);

    // Verify Supermarket categories count (9 categories)
    expect(CommunicationData.supermarketCategories.length, 9);

    // Verify category 1 Sinhala and English texts render
    expect(find.text('මූලික සන්නිවේදනය'), findsOneWidget);
    expect(find.text('Basic communication'), findsOneWidget);

    // Verify supermarket chip
    expect(find.text('Supermarket (9 Cat.)'), findsOneWidget);
  });
}
