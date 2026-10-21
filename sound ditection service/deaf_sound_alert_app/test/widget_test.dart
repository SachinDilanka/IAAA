import 'package:flutter_test/flutter_test.dart';
import 'package:deaf_sound_alert_app/main.dart';

void main() {
  testWidgets('App load test', (WidgetTester tester) async {
    await tester.pumpWidget(const DeafSoundAlertApp());
  });
}
