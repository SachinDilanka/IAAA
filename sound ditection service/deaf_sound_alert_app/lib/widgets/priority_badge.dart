import 'package:flutter/material.dart';
import '../models/detected_sound.dart';

class PriorityBadge extends StatelessWidget {
  final PriorityLevel priority;
  final bool showIcon;

  const PriorityBadge({
    super.key,
    required this.priority,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: priority.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: priority.color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(priority.icon, size: 14, color: priority.color),
            const SizedBox(width: 4),
          ],
          Text(
            priority.displayName,
            style: TextStyle(
              color: priority.color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

