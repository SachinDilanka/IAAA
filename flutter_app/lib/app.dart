import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/app/app_controller.dart';
import 'features/guardian/guardian_screen.dart';
import 'features/home/home_screen.dart';
import 'features/practice/letter_practice_screen.dart';
import 'features/practice/word_practice_screen.dart';
import 'features/progress/progress_screen.dart';
import 'l10n/generated/app_localizations.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/letters', builder: (_, _) => const LetterPracticeScreen()),
    GoRoute(path: '/words', builder: (_, _) => const WordPracticeScreen()),
    GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
    GoRoute(path: '/guardian', builder: (_, _) => const GuardianScreen()),
  ],
);

class SpeechTherapyApp extends StatelessWidget {
  const SpeechTherapyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.select<AppController, Locale>(
      (controller) => controller.locale,
    );
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}
