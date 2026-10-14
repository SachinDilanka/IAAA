import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../features/app/app_controller.dart';
import '../../l10n/l10n.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<AppController>().progress;
    return AppScaffold(
      currentIndex: 0,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WelcomeBanner(stars: progress.stars),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1040
                    ? 4
                    : constraints.maxWidth >= 620
                    ? 2
                    : 1;
                const spacing = 18.0;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                final cards = [
                  _ActivityCard(
                    emoji: '🔤',
                    title: context.l10n.letterPractice,
                    description: context.l10n.letterPracticeDescription,
                    action: context.l10n.start,
                    color: const Color(0xFFDB2777),
                    onTap: () => context.go('/letters'),
                  ),
                  _ActivityCard(
                    emoji: '🧩',
                    title: context.l10n.wordPractice,
                    description: context.l10n.wordPracticeDescription,
                    action: context.l10n.start,
                    color: const Color(0xFFEA580C),
                    onTap: () => context.go('/words'),
                  ),
                  _ActivityCard(
                    emoji: '📷',
                    title: context.l10n.cameraPractice,
                    description: context.l10n.cameraPracticeDescription,
                    action: context.l10n.start,
                    color: const Color(0xFF059669),
                    onTap: () => context.go('/words'),
                  ),
                  _ActivityCard(
                    emoji: '🏆',
                    title: context.l10n.myProgress,
                    description: context.l10n.progressDescription,
                    action: context.l10n.viewProgress,
                    color: AppColors.violet,
                    onTap: () => context.go('/progress'),
                  ),
                ];
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: cards
                      .map((card) => SizedBox(width: width, child: card))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x336366F1),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 24,
        runSpacing: 20,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.l10n.hello} 👋',
                  style: Theme.of(context).textTheme.headlineLarge
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.welcomeMessage,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                            context.l10n.listen,
                            context.l10n.speak,
                            context.l10n.earnStars,
                          ]
                          .map(
                            (text) => Chip(
                              label: Text(text),
                              backgroundColor: Colors.white,
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
          Chip(
            avatar: const Icon(Icons.star_rounded, color: AppColors.gold),
            label: Text(
              '$stars ${context.l10n.stars}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(10),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.action,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String description;
  final String action;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 290),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 34)),
                ),
                const SizedBox(height: 20),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(description),
                const Spacer(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      action,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(Icons.arrow_forward_rounded, color: color),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
