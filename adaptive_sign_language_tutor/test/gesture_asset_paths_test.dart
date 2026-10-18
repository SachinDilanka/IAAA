import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adaptive_sign_language_tutor/core/utils/gesture_asset_paths.dart';
import 'package:adaptive_sign_language_tutor/presentation/screens/avatar_lib/avatar_library_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GestureAssetPaths', () {
    test('maps alphabet signs to extracted dataset files', () {
      expect(
        GestureAssetPaths.forLetter('A'),
        'dataset/landmarks/letter/a/a.json',
      );
      expect(
        GestureAssetPaths.forLetter('B'),
        'dataset/landmarks/letter/b_first_way/b_first_way.json',
      );
      expect(GestureAssetPaths.forLetter('N'), isNull);
    });

    test('maps month signs including nonstandard source filenames', () {
      expect(
        GestureAssetPaths.forMonth('January'),
        'dataset/landmarks/month/january/january.json',
      );
      expect(
        GestureAssetPaths.forMonth('March'),
        'dataset/landmarks/month/march/mrach.json',
      );
      expect(
        GestureAssetPaths.forMonth('September'),
        'dataset/landmarks/month/september/september_similar_to_s.json',
      );
    });

    test('maps verb signs to their extracted dataset files', () {
      expect(
        GestureAssetPaths.forVerb('adinawa'),
        'dataset/landmarks/verb/adinawa/adinawa.json',
      );
      expect(
        GestureAssetPaths.forVerb('adum_sodanawa'),
        'dataset/landmarks/verb/adum_sodanawa/adum_sodanawa.json',
      );
      expect(
        GestureAssetPaths.forVerb('hinawenawa'),
        'dataset/landmarks/verb/hinawenawa/hinawenawa.json',
      );
    });

    test('recognizes month dataset paths on Windows and other platforms', () {
      expect(
        GestureAssetPaths.isMonthAsset(
          r'dataset\landmarks\month\january\january.json',
        ),
        isTrue,
      );
      expect(
        GestureAssetPaths.isMonthAsset('dataset/landmarks/letter/a/a.json'),
        isFalse,
      );
      expect(
        GestureAssetPaths.isDynamicAsset(
          'dataset/landmarks/verb/adinawa/adinawa.json',
        ),
        isTrue,
      );
    });

    test('maps dataset paths to generated avatar animation clips', () {
      expect(
        GestureAssetPaths.animationNameFor(
          'dataset/landmarks/letter/b_first_way/b_first_way.json',
        ),
        'letter_b_first_way',
      );
      expect(
        GestureAssetPaths.animationNameFor(
          'dataset/landmarks/month/march/mrach.json',
          playbackSpeed: 0.75,
        ),
        'month_march_0_75x',
      );
      expect(
        GestureAssetPaths.animationNameFor(
          'dataset/landmarks/verb/adinawa/adinawa.json',
          playbackSpeed: 0.5,
        ),
        'verb_adinawa_0_5x',
      );
      expect(
        GestureAssetPaths.animationNameFor('assets/gestures/unknown.json'),
        isNull,
      );
    });

    test(
      'loads regenerated gesture files from the Flutter asset bundle',
      () async {
        for (final assetPath in [
          GestureAssetPaths.forLetter('A')!,
          GestureAssetPaths.forMonth('January'),
          GestureAssetPaths.forMonth('March'),
          GestureAssetPaths.forMonth('September'),
          GestureAssetPaths.forVerb('adinawa'),
          GestureAssetPaths.forVerb('hinawenawa'),
        ]) {
          final json = await rootBundle.loadString(assetPath);
          expect(json, startsWith('['), reason: assetPath);
        }
      },
    );
  });

  testWidgets('library shows all verb names in Sinhala', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AvatarLibraryScreen()));
    await tester.tap(find.text('Verbs'));
    await tester.pumpAndSettle();

    final verbNames = [
      'අදිනවා',
      'ඇඳුම් සෝදනවා',
      'අහනවා',
      'අඬනවා',
      'අතු ගානවා',
      'ඇවිදිනවා',
      'බොනවා',
      'දුවනවා',
      'හිනාවෙනවා',
      'කෑමක් හදනවා',
      'කනවා',
      'ලියනවා',
      'මූණ සෝදනවා',
      'නානවා',
      'නැගිටිනවා',
      'පාඩම් කරනවා',
      'පනිනවා',
      'සොයනවා',
      'උදව් කරනවා',
      'වාඩි වෙනවා',
    ];
    final grid = find.byType(Scrollable).last;
    for (final name in verbNames) {
      await tester.scrollUntilVisible(find.text(name), 180, scrollable: grid);
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });
}
