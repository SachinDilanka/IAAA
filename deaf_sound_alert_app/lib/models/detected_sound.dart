import 'package:flutter/material.dart';

enum PriorityLevel { high, medium, low }

extension PriorityLevelExtension on PriorityLevel {
  String get displayName {
    switch (this) {
      case PriorityLevel.high:
        return 'HIGH';
      case PriorityLevel.medium:
        return 'MEDIUM';
      case PriorityLevel.low:
        return 'LOW';
    }
  }

  Color get color {
    switch (this) {
      case PriorityLevel.high:
        return const Color(0xFFFF3B30); // Bright Red
      case PriorityLevel.medium:
        return const Color(0xFFFF9500); // Vibrant Amber
      case PriorityLevel.low:
        return const Color(0xFF34C759); // Emerald Green / Teal
    }
  }

  IconData get icon {
    switch (this) {
      case PriorityLevel.high:
        return Icons.warning_amber_rounded;
      case PriorityLevel.medium:
        return Icons.info_outline_rounded;
      case PriorityLevel.low:
        return Icons.volume_down_rounded;
    }
  }
}

class DetectedSound {
  final String id;
  final String soundKey;
  final String soundName;
  final String category; // 'Sinhala Keyword' or 'Environmental Sound'
  final PriorityLevel priority;
  final double confidence;
  final DateTime timestamp;

  DetectedSound({
    required this.id,
    required this.soundKey,
    required this.soundName,
    required this.category,
    required this.priority,
    required this.confidence,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'soundKey': soundKey,
        'soundName': soundName,
        'category': category,
        'priority': priority.name,
        'confidence': confidence,
        'timestamp': timestamp.toIso8601String(),
      };

  factory DetectedSound.fromJson(Map<String, dynamic> json) => DetectedSound(
        id: json['id'],
        soundKey: json['soundKey'],
        soundName: json['soundName'],
        category: json['category'],
        priority: PriorityLevel.values.firstWhere(
          (p) => p.name == json['priority'],
          orElse: () => PriorityLevel.medium,
        ),
        confidence: (json['confidence'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp']),
      );
}

