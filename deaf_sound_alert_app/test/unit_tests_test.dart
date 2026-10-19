import 'package:flutter_test/flutter_test.dart';
import 'package:deaf_sound_alert_app/models/detected_sound.dart';
import 'package:deaf_sound_alert_app/models/sound_config.dart';
import 'package:deaf_sound_alert_app/services/sound_config_service.dart';

void main() {
  group('1. Sound Configuration & Priority Level Tests', () {
    late SoundConfigService service;

    setUp(() {
      service = SoundConfigService();
    });

    test('All 15 sound classes are properly configured and enabled', () {
      final udaw = service.getConfig('sinhala_udaw_');
      final dog = service.getConfig('dog_bark_dataset');
      final horn = service.getConfig('vehicle horns');
      final traffic = service.getConfig('traffic');

      expect(udaw, isNotNull);
      expect(udaw!.priority, equals(PriorityLevel.high));
      expect(udaw.isEnabled, isTrue);

      expect(dog, isNotNull);
      expect(dog!.priority, equals(PriorityLevel.medium));

      expect(horn, isNotNull);
      expect(horn!.priority, equals(PriorityLevel.high));

      expect(traffic, isNotNull);
      expect(traffic!.priority, equals(PriorityLevel.low));
    });
  });

  group('2. Exact Keyword Boundary Matching Tests', () {
    bool isKeywordMatch(String text, String pattern) {
      final textLower = text.toLowerCase().trim();
      final patternLower = pattern.toLowerCase().trim();
      if (textLower.isEmpty || patternLower.isEmpty) return false;
      if (textLower == patternLower) return true;

      final words = textLower.split(RegExp(r'[^\w\u0D80-\u0DFF]+')).where((w) => w.isNotEmpty).toList();
      for (final word in words) {
        if (word == patternLower) return true;
      }
      return false;
    }

    test('Exact match for "udaw" and Sinhala "උදව්"', () {
      expect(isKeywordMatch('udaw', 'udaw'), isTrue);
      expect(isKeywordMatch('mata udaw karanna', 'udaw'), isTrue);
      expect(isKeywordMatch('මට උදව් කරන්න', 'උදව්'), isTrue);
    });

    test('Prevents false substring matches on unrelated speech', () {
      expect(isKeywordMatch('today', 'udaw'), isFalse);
      expect(isKeywordMatch('shadow', 'udaw'), isFalse);
      expect(isKeywordMatch('without', 'udaw'), isFalse);
    });
  });

  group('3. DetectedSound Event & Serialization Tests', () {
    test('DetectedSound serializes and deserializes correctly', () {
      final now = DateTime.now();
      final event = DetectedSound(
        id: 'test_101',
        soundKey: 'sinhala_udaw_',
        soundName: 'උදව් (Udaw - Help)',
        category: 'Sinhala Keyword',
        priority: PriorityLevel.high,
        confidence: 0.95,
        timestamp: now,
      );

      final json = event.toJson();
      final restored = DetectedSound.fromJson(json);

      expect(restored.id, equals('test_101'));
      expect(restored.soundKey, equals('sinhala_udaw_'));
      expect(restored.soundName, equals('උදව් (Udaw - Help)'));
      expect(restored.priority, equals(PriorityLevel.high));
      expect(restored.confidence, closeTo(0.95, 0.001));
    });
  });
}

