import 'detected_sound.dart';

class SoundConfig {
  final String key;
  final String name;
  final String category;
  PriorityLevel priority;
  bool isEnabled;

  SoundConfig({
    required this.key,
    required this.name,
    required this.category,
    required this.priority,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'category': category,
        'priority': priority.name,
        'isEnabled': isEnabled,
      };

  factory SoundConfig.fromJson(Map<String, dynamic> json) => SoundConfig(
        key: json['key'],
        name: json['name'],
        category: json['category'],
        priority: PriorityLevel.values.firstWhere(
          (p) => p.name == json['priority'],
          orElse: () => PriorityLevel.medium,
        ),
        isEnabled: json['isEnabled'] ?? true,
      );
}

