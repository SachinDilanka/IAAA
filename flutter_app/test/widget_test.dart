import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinhala_speech_therapy/core/widgets/confirmation_dialog.dart';
import 'package:sinhala_speech_therapy/l10n/generated/app_localizations.dart';
import 'package:sinhala_speech_therapy/l10n/l10n.dart';

void main() {
  testWidgets('confirmation dialog is centered and closes with OK', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showConfirmationDialog(
                  context,
                  title: context.l10n.profileUpdated,
                  message: 'Your changes were saved successfully.',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Profile updated!'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    final screenCenter = tester.getCenter(find.byType(Scaffold));
    final dialogCenter = tester.getCenter(find.byType(Dialog));
    expect((screenCenter - dialogCenter).distance, lessThan(2));

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}
