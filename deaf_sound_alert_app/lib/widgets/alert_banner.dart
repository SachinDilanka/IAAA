import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/detected_sound.dart';
import 'priority_badge.dart';

class AlertBanner extends StatelessWidget {
  final DetectedSound sound;
  final VoidCallback? onDismiss;

  const AlertBanner({
    super.key,
    required this.sound,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isHigh = sound.priority == PriorityLevel.high;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: sound.priority.color.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sound.priority.color, width: isHigh ? 3 : 2),
        boxShadow: [
          BoxShadow(
            color: sound.priority.color.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(sound.priority.icon, color: sound.priority.color, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    sound.category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  PriorityBadge(priority: sound.priority),
                  if (onDismiss != null) ...[
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onDismiss,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF3B30).withValues(alpha: 0.8),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            sound.soundName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: sound.priority.color,
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Confidence: ${(sound.confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                DateFormat('hh:mm:ss a').format(sound.timestamp),
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
