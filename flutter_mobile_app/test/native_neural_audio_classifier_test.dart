import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_alert_system/ai/native_neural_audio_classifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeNeuralAudioClassifier Real Audio Tests', () {
    final classifier = NativeNeuralAudioClassifier();

    test('Accurately classifies real environmental audio dataset samples', () async {
      await classifier.loadModel();
      expect(classifier.isLoaded, isTrue);

      final sampleJsonStr = await rootBundle.loadString('assets/models/test_audio_samples.json');
      final sampleMap = jsonDecode(sampleJsonStr) as Map<String, dynamic>;

      // 1. Baby crying
      final baby = (sampleMap['baby_crying'] as List).map((e) => (e as num).toDouble()).toList();
      final babyPred = classifier.predict(baby);
      print('Dart Baby Crying Pred: ${babyPred?.label} (${babyPred?.probability})');
      expect(babyPred?.label, equals('baby_crying'));

      // 2. Ambulance
      final ambulance = (sampleMap['ambulance'] as List).map((e) => (e as num).toDouble()).toList();
      final ambPred = classifier.predict(ambulance);
      print('Dart Ambulance Pred: ${ambPred?.label} (${ambPred?.probability})');
      expect(ambPred?.label, equals('ambulance_siren'));

      // 3. Fire / Ginnak
      final firetruck = (sampleMap['firetruck'] as List).map((e) => (e as num).toDouble()).toList();
      final firePred = classifier.predict(firetruck);
      print('Dart Firetruck Pred: ${firePred?.label} (${firePred?.probability})');
      expect(firePred?.label, equals('ginnak'));

      // 4. Horn
      final horn = (sampleMap['horn'] as List).map((e) => (e as num).toDouble()).toList();
      final hornPred = classifier.predict(horn);
      print('Dart Horn Pred: ${hornPred?.label} (${hornPred?.probability})');
      expect(hornPred?.label, equals('vehicle_horn'));

      // 5. Dog Bark
      final dog = (sampleMap['dog_bark'] as List).map((e) => (e as num).toDouble()).toList();
      final dogPred = classifier.predict(dog);
      print('Dart Dog Bark Pred: ${dogPred?.label} (${dogPred?.probability})');
      expect(dogPred?.label, equals('dog_barking'));
    });
  });
}
