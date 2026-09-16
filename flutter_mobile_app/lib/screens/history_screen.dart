import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../storage/history_database.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Detection History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            onPressed: () {
              Provider.of<HistoryDatabase>(context, listen: false).clearHistory();
            },
          ),
        ],
      ),
      body: Consumer<HistoryDatabase>(
        builder: (context, db, child) {
          final history = db.history;
          if (history.isEmpty) {
            return const Center(
              child: Text(
                'No detection history recorded.',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final event = history[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: event.priority.color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: event.priority.color.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(event.priority.icon, color: event.priority.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.titleEnglish,
                            style: const TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            event.titleSinhala,
                            style: const TextStyle(
                              color: Color(0xFFF1F5F9),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy-MM-dd   hh:mm:ss a').format(event.timestamp),
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: event.priority.color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            event.priority.name,
                            style: TextStyle(
                              color: event.priority.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(event.confidence * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: event.priority.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
