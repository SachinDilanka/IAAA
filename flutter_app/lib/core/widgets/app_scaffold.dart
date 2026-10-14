import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/app/app_controller.dart';
import '../../l10n/l10n.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.currentIndex,
    required this.child,
    this.title,
  });

  final int currentIndex;
  final Widget child;
  final String? title;

  static const _routes = ['/', '/letters', '/words', '/progress', '/guardian'];

  void _navigate(BuildContext context, int index) => context.go(_routes[index]);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final labels = [
      context.l10n.home,
      context.l10n.letters,
      context.l10n.words,
      context.l10n.progress,
      context.l10n.guardian,
    ];
    const icons = [
      Icons.home_rounded,
      Icons.text_fields_rounded,
      Icons.auto_awesome_rounded,
      Icons.insights_rounded,
      Icons.family_restroom_rounded,
    ];

    final content = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0F9FF), Color(0xFFFFFBEB), Color(0xFFF5F3FF)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: child,
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        backgroundColor: Colors.white.withValues(alpha: .96),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 18,
        title: Row(
          children: [
            const Text('🦁', style: TextStyle(fontSize: 36)),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? context.l10n.appTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    context.l10n.appSubtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: context.l10n.language,
            icon: const Icon(Icons.language_rounded),
            initialValue: controller.locale.languageCode,
            onSelected: (value) => controller.setLocale(Locale(value)),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'si', child: Text(context.l10n.sinhala)),
              PopupMenuItem(value: 'en', child: Text(context.l10n.english)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: const CircleAvatar(child: Text('👦')),
              label: Text(controller.child?.name ?? context.l10n.childProfile),
              onPressed: () => context.go('/guardian'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 840) return content;
          return Row(
            children: [
              NavigationRail(
                selectedIndex: currentIndex,
                onDestinationSelected: (index) => _navigate(context, index),
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.white,
                destinations: List.generate(
                  labels.length,
                  (index) => NavigationRailDestination(
                    icon: Icon(icons[index]),
                    label: Text(labels[index]),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          );
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 840
          ? NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) => _navigate(context, index),
              destinations: List.generate(
                labels.length,
                (index) => NavigationDestination(
                  icon: Icon(icons[index]),
                  label: labels[index],
                ),
              ),
            )
          : null,
    );
  }
}
