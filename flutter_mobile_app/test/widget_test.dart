import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_alert_system/main.dart';
import 'package:sound_alert_system/ai/sound_classifier_service.dart';
import 'package:sound_alert_system/avatar/avatar_controller.dart';
import 'package:sound_alert_system/wearable/smartwatch_service.dart';
import 'package:sound_alert_system/storage/history_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SoundAlertApp renders and displays navigation host', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final avatarController = AvatarController();
    final classifierService = SoundClassifierService();
    classifierService.attachAvatarController(avatarController);
    final historyDb = HistoryDatabase();
    await historyDb.loadHistory();
    final smartwatchService = SmartwatchService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: avatarController),
          ChangeNotifierProvider.value(value: classifierService),
          ChangeNotifierProvider.value(value: smartwatchService),
          ChangeNotifierProvider.value(value: historyDb),
        ],
        child: const SoundAlertApp(),
      ),
    );

    expect(find.byType(NavigationHostScreen), findsOneWidget);
  });
}
