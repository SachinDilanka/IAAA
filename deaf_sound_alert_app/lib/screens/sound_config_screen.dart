import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/detected_sound.dart';
import '../widgets/priority_badge.dart';

class SoundConfigScreen extends StatelessWidget {
  const SoundConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.soundConfigs.length,
          itemBuilder: (context, index) {
            final config = provider.soundConfigs[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: config.priority.color.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Switch(
                        value: config.isEnabled,
                        activeColor: config.priority.color,
                        onChanged: (val) => provider.toggleSoundEnabled(config.key, val),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config.name,
                              style: TextStyle(
                                color: config.isEnabled ? Colors.white : Colors.white38,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              config.category,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      PriorityBadge(priority: config.priority),
                    ],
                  ),
                  if (config.isEnabled) ...[
                    const Divider(color: Colors.white10, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Priority Level:',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        SegmentedButton<PriorityLevel>(
                          segments: const [
                            ButtonSegment(
                              value: PriorityLevel.high,
                              label: Text('HIGH', style: TextStyle(fontSize: 10)),
                            ),
                            ButtonSegment(
                              value: PriorityLevel.medium,
                              label: Text('MED', style: TextStyle(fontSize: 10)),
                            ),
                            ButtonSegment(
                              value: PriorityLevel.low,
                              label: Text('LOW', style: TextStyle(fontSize: 10)),
                            ),
                          ],
                          selected: {config.priority},
                          onSelectionChanged: (Set<PriorityLevel> selected) {
                            provider.updateSoundPriority(config.key, selected.first);
                          },
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

