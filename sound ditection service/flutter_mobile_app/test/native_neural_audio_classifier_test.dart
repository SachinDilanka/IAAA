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

      // 1. Sinhala Keyword "udaw"
      final udaw = (sampleMap['udaw'] as List).map((e) => (e as num).toDouble()).toList();
      final udawPred = classifier.predict(udaw);
      print('Dart Udaw Pred: ${udawPred?.label} (${udawPred?.probability})');
      expect(udawPred?.label, equals('udaw'));

      // 2. Sinhala Keyword "beeraganna"
      final beeraganna = (sampleMap['beeraganna'] as List).map((e) => (e as num).toDouble()).toList();
      final beeragannaPred = classifier.predict(beeraganna);
      print('Dart Beeraganna Pred: ${beeragannaPred?.label} (${beeragannaPred?.probability})');
      expect(beeragannaPred?.label, equals('beeraganna'));

      // 3. Sinhala Keyword "ginnak"
      final ginnak = (sampleMap['ginnak'] as List).map((e) => (e as num).toDouble()).toList();
      final ginnakPred = classifier.predict(ginnak);
      print('Dart Ginnak Pred: ${ginnakPred?.label} (${ginnakPred?.probability})');
      expect(ginnakPred?.label, equals('ginnak'));

      // 4. Sinhala Keyword "anathurak"
      final anathurak = (sampleMap['anathurak'] as List).map((e) => (e as num).toDouble()).toList();
      final anathurakPred = classifier.predict(anathurak);
      print('Dart Anathurak Pred: ${anathurakPred?.label} (${anathurakPred?.probability})');
      expect(anathurakPred?.label, equals('anathurak'));

      // 5. Sinhala Keyword "karadarayak"
      final karadarayak = (sampleMap['karadarayak'] as List).map((e) => (e as num).toDouble()).toList();
      final karadarayakPred = classifier.predict(karadarayak);
      print('Dart Karadarayak Pred: ${karadarayakPred?.label} (${karadarayakPred?.probability})');
      expect(karadarayakPred?.label, equals('karadarayak'));

      // 6. Sinhala Keyword "balagena"
      final balagena = (sampleMap['balagena'] as List).map((e) => (e as num).toDouble()).toList();
      final balagenaPred = classifier.predict(balagena);
      print('Dart Balagena Pred: ${balagenaPred?.label} (${balagenaPred?.probability})');
      expect(balagenaPred?.label, equals('balagena'));

      // 7. Sinhala Keyword "parissamin"
      final parissamin = (sampleMap['parissamin'] as List).map((e) => (e as num).toDouble()).toList();
      final parissaminPred = classifier.predict(parissamin);
      print('Dart Parissamin Pred: ${parissaminPred?.label} (${parissaminPred?.probability})');
      expect(parissaminPred?.label, equals('parissamin'));

      // 8. Sinhala Keyword "ehata_wenna"
      final ehataWenna = (sampleMap['ehata_wenna'] as List).map((e) => (e as num).toDouble()).toList();
      final ehataWennaPred = classifier.predict(ehataWenna);
      print('Dart Ehata Wenna Pred: ${ehataWennaPred?.label} (${ehataWennaPred?.probability})');
      expect(ehataWennaPred?.label, equals('ehata_wenna'));

      // 9. Baby crying
      final baby = (sampleMap['baby_crying'] as List).map((e) => (e as num).toDouble()).toList();
      final babyPred = classifier.predict(baby);
      print('Dart Baby Crying Pred: ${babyPred?.label} (${babyPred?.probability})');
      expect(babyPred?.label, equals('baby_crying'));

      // 10. Ambulance Siren
      final ambulance = (sampleMap['ambulance'] as List).map((e) => (e as num).toDouble()).toList();
      final ambPred = classifier.predict(ambulance);
      print('Dart Ambulance Pred: ${ambPred?.label} (${ambPred?.probability})');
      expect(ambPred?.label, equals('ambulance_siren'));

      // 11. Vehicle Horn
      final horn = (sampleMap['horn'] as List).map((e) => (e as num).toDouble()).toList();
      final hornPred = classifier.predict(horn);
      print('Dart Horn Pred: ${hornPred?.label} (${hornPred?.probability})');
      expect(hornPred?.label, equals('vehicle_horn'));

      // 12. Dog Barking
      final dog = (sampleMap['dog_bark'] as List).map((e) => (e as num).toDouble()).toList();
      final dogPred = classifier.predict(dog);
      print('Dart Dog Bark Pred: ${dogPred?.label} (${dogPred?.probability})');
      expect(dogPred?.label, equals('dog_barking'));

      // 13. Background Traffic
      final traffic = (sampleMap['traffic'] as List).map((e) => (e as num).toDouble()).toList();
      final trafficPred = classifier.predict(traffic);
      print('Dart Traffic Pred: ${trafficPred?.label} (${trafficPred?.probability})');
      expect(trafficPred?.label, equals('background_traffic'));
    });
  });
}
