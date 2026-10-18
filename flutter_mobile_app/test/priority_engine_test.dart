import 'package:flutter_test/flutter_test.dart';
import 'package:sound_alert_system/services/priority_engine.dart';
import 'package:sound_alert_system/models/alert_level.dart';

void main() {
  group('PriorityEngine Sinhala Emergency Dataset Tests', () {
    late PriorityEngine engine;

    setUp(() {
      engine = PriorityEngine();
    });

    test('All 7 Sinhala emergency keywords are correctly mapped to priority levels', () {
      // 1. udaw -> High Priority
      final udawEvent = engine.processPrediction(rawClass: 'udaw', confidence: 0.95);
      expect(udawEvent, isNotNull);
      expect(udawEvent!.priority, equals(AlertLevel.high));
      expect(udawEvent.titleSinhala, contains('උදව්'));

      // 2. beeraganna -> High Priority
      final beeragannaEvent = engine.processPrediction(rawClass: 'beeraganna', confidence: 0.94);
      expect(beeragannaEvent, isNotNull);
      expect(beeragannaEvent!.priority, equals(AlertLevel.high));
      expect(beeragannaEvent.titleSinhala, contains('බේරගන්න'));

      // 3. ginnak -> High Priority
      final ginnakEvent = engine.processPrediction(rawClass: 'ginnak', confidence: 0.93);
      expect(ginnakEvent, isNotNull);
      expect(ginnakEvent!.priority, equals(AlertLevel.high));
      expect(ginnakEvent.titleSinhala, contains('ගින්නක්'));

      // 4. anathurak -> High Priority
      final anathurakEvent = engine.processPrediction(rawClass: 'anathurak', confidence: 0.92);
      expect(anathurakEvent, isNotNull);
      expect(anathurakEvent!.priority, equals(AlertLevel.high));
      expect(anathurakEvent.titleSinhala, contains('අනතුරක්'));

      // 5. karadarayak -> Medium Priority
      final karadarayakEvent = engine.processPrediction(rawClass: 'karadarayak', confidence: 0.88);
      expect(karadarayakEvent, isNotNull);
      expect(karadarayakEvent!.priority, equals(AlertLevel.medium));
      expect(karadarayakEvent.titleSinhala, contains('කරදරයක්'));

      // 6. balagena -> Medium Priority
      final balagenaEvent = engine.processPrediction(rawClass: 'balagena', confidence: 0.87);
      expect(balagenaEvent, isNotNull);
      expect(balagenaEvent!.priority, equals(AlertLevel.medium));
      expect(balagenaEvent.titleSinhala, contains('බලාගෙන'));

      // 7. parissamin -> Medium Priority
      final parissaminEvent = engine.processPrediction(rawClass: 'parissamin', confidence: 0.86);
      expect(parissaminEvent, isNotNull);
      expect(parissaminEvent!.priority, equals(AlertLevel.medium));
      expect(parissaminEvent.titleSinhala, contains('පරිස්සමින්'));
    });

    test('Environmental emergency sounds are accurately classified', () {
      final fireAlarm = engine.processPrediction(rawClass: 'fire_alarm', confidence: 0.96);
      expect(fireAlarm, isNotNull);
      expect(fireAlarm!.priority, equals(AlertLevel.high));

      final dogBark = engine.processPrediction(rawClass: 'dog_barking', confidence: 0.85);
      expect(dogBark, isNotNull);
      expect(dogBark!.priority, equals(AlertLevel.low));

      final bgNoise = engine.processPrediction(rawClass: 'background_other', confidence: 0.99);
      expect(bgNoise, isNull);
    });
  });
}
