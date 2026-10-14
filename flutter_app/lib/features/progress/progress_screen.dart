import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/progress_summary.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/loading_error_view.dart';
import '../../l10n/l10n.dart';
import '../app/app_controller.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return AppScaffold(
      currentIndex: 3,
      title: context.l10n.myProgress,
      child: RefreshIndicator(
        onRefresh: controller.refreshProgress,
        child: controller.isLoading && controller.progress.available == 0
            ? const Center(child: CircularProgressIndicator())
            : controller.loadError != null && controller.progress.available == 0
            ? ListView(
                children: [
                  SizedBox(
                    height: 500,
                    child: LoadingErrorView(onRetry: controller.reload),
                  ),
                ],
              )
            : _ProgressContent(progress: controller.progress),
      ),
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({required this.progress});
  final ProgressSummary progress;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth < 650
                ? constraints.maxWidth
                : (constraints.maxWidth - 32) / 3;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  width: cardWidth,
                  icon: Icons.task_alt_rounded,
                  value: '${progress.completed}',
                  label: context.l10n.completedActivities,
                  color: const Color(0xFF0EA5E9),
                ),
                _StatCard(
                  width: cardWidth,
                  icon: Icons.star_rounded,
                  value: '${progress.stars}',
                  label: context.l10n.starsEarned,
                  color: const Color(0xFFF59E0B),
                ),
                _StatCard(
                  width: cardWidth,
                  icon: Icons.insights_rounded,
                  value: '${progress.percent}%',
                  label: context.l10n.overallProgress,
                  color: const Color(0xFF8B5CF6),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.recentPractice,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                if (progress.history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        context.l10n.noPractice,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...progress.history.map((item) => _HistoryTile(item: item)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final double width;
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: color),
                    ),
                    Text(label),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});
  final PracticeHistory item;

  String _emotion(BuildContext context) => switch (item.emotion) {
    'happy' => context.l10n.happy,
    'surprise' => context.l10n.surprise,
    'sad' => context.l10n.sad,
    'fear' => context.l10n.fear,
    'angry' => context.l10n.angry,
    'disgust' => context.l10n.disgust,
    _ => context.l10n.neutral,
  };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEEF2FF),
        child: Text(item.sinhalaText.characters.firstOrNull ?? '⭐'),
      ),
      title: Text(
        item.sinhalaText,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text('${_emotion(context)} · ${item.date}'),
      trailing: Chip(
        avatar: const Icon(
          Icons.star_rounded,
          color: Color(0xFFF59E0B),
          size: 19,
        ),
        label: Text('${item.stars}'),
      ),
    );
  }
}
