import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/detected_sound.dart';
import '../widgets/priority_badge.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  PriorityLevel? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final filteredHistory = _selectedFilter == null
            ? provider.history
            : provider.history.where((e) => e.priority == _selectedFilter).toList();

        return Column(
          children: [
            // Filter Pills & Clear Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('ALL'),
                            selected: _selectedFilter == null,
                            selectedColor: Colors.cyanAccent.withOpacity(0.3),
                            onSelected: (_) => setState(() => _selectedFilter = null),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('HIGH'),
                            selected: _selectedFilter == PriorityLevel.high,
                            selectedColor: PriorityLevel.high.color.withOpacity(0.3),
                            onSelected: (_) => setState(() => _selectedFilter = PriorityLevel.high),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('MEDIUM'),
                            selected: _selectedFilter == PriorityLevel.medium,
                            selectedColor: PriorityLevel.medium.color.withOpacity(0.3),
                            onSelected: (_) => setState(() => _selectedFilter = PriorityLevel.medium),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('LOW'),
                            selected: _selectedFilter == PriorityLevel.low,
                            selectedColor: PriorityLevel.low.color.withOpacity(0.3),
                            onSelected: (_) => setState(() => _selectedFilter = PriorityLevel.low),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white70),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E2C),
                          title: const Text('Clear History?', style: TextStyle(color: Colors.white)),
                          content: const Text('Do you want to clear all sound logs?', style: TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                provider.clearHistory();
                                Navigator.pop(ctx);
                              },
                              child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // History List
            Expanded(
              child: filteredHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.history_rounded, size: 64, color: Colors.white24),
                          SizedBox(height: 16),
                          Text(
                            'No sound events logged yet',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredHistory.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final item = filteredHistory[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.priority.color.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: item.priority.color.withOpacity(0.2),
                                radius: 24,
                                child: Icon(item.soundIcon, color: item.priority.color),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.soundName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.category} • ${(item.confidence * 100).toStringAsFixed(0)}% match',
                                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PriorityBadge(priority: item.priority),
                                      const SizedBox(width: 8),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => provider.removeHistoryEvent(item.id),
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            alignment: Alignment.center,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFFF3B30),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    DateFormat('hh:mm a').format(item.timestamp),
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

