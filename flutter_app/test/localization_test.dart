import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinhala_speech_therapy/l10n/generated/app_localizations.dart';

void main() {
  test('English and Sinhala resources provide localized interface text', () {
    final english = lookupAppLocalizations(const Locale('en'));
    final sinhala = lookupAppLocalizations(const Locale('si'));

    expect(english.appTitle, 'Little Voices');
    expect(sinhala.appTitle, 'සිඟිති කතා');
    expect(english.saveProfile, isNot(sinhala.saveProfile));
    expect(english.profileUpdatedMessage('Nimali'), contains('Nimali'));
    expect(sinhala.profileUpdatedMessage('නිමාලි'), contains('නිමාලි'));
  });
}
