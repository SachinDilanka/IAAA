import 'alert_level.dart';

class DetectionEvent {
  final String id;
  final String rawClass;
  final String titleEnglish;
  final String titleSinhala;
  final AlertLevel priority;
  final double confidence;
  final DateTime timestamp;
  final String avatarGuidanceEnglish;
  final String avatarGuidanceSinhala;

  DetectionEvent({
    required this.id,
    required this.rawClass,
    required this.titleEnglish,
    required this.titleSinhala,
    required this.priority,
    required this.confidence,
    required this.timestamp,
    required this.avatarGuidanceEnglish,
    required this.avatarGuidanceSinhala,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'rawClass': rawClass,
        'titleEnglish': titleEnglish,
        'titleSinhala': titleSinhala,
        'priority': priority.name,
        'confidence': confidence,
        'timestamp': timestamp.toIso8601String(),
        'avatarGuidanceEnglish': avatarGuidanceEnglish,
        'avatarGuidanceSinhala': avatarGuidanceSinhala,
      };

  factory DetectionEvent.fromJson(Map<String, dynamic> json) {
    return DetectionEvent(
      id: json['id'] as String,
      rawClass: json['rawClass'] as String,
      titleEnglish: json['titleEnglish'] as String,
      titleSinhala: json['titleSinhala'] as String,
      priority: AlertLevel.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => AlertLevel.low,
      ),
      confidence: (json['confidence'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      avatarGuidanceEnglish: json['avatarGuidanceEnglish'] as String,
      avatarGuidanceSinhala: json['avatarGuidanceSinhala'] as String,
    );
  }
}
