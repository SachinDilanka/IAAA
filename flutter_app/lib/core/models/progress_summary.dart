class PracticeHistory {
  const PracticeHistory({
    required this.id,
    required this.sinhalaText,
    required this.category,
    required this.stars,
    required this.emotion,
    required this.date,
  });

  final int id;
  final String sinhalaText;
  final String category;
  final int stars;
  final String? emotion;
  final String date;

  factory PracticeHistory.fromJson(Map<String, dynamic> json) =>
      PracticeHistory(
        id: json['id'] as int,
        sinhalaText: json['sinhala_text'] as String? ?? '',
        category: json['category'] as String? ?? '',
        stars: json['stars'] as int? ?? 0,
        emotion: json['emotion'] as String?,
        date: json['date'] as String? ?? '',
      );
}

class ProgressSummary {
  const ProgressSummary({
    required this.completed,
    required this.available,
    required this.percent,
    required this.stars,
    required this.history,
  });

  static const empty = ProgressSummary(
    completed: 0,
    available: 0,
    percent: 0,
    stars: 0,
    history: [],
  );

  final int completed;
  final int available;
  final int percent;
  final int stars;
  final List<PracticeHistory> history;

  factory ProgressSummary.fromJson(Map<String, dynamic> json) =>
      ProgressSummary(
        completed: json['total_completed'] as int? ?? 0,
        available: json['total_available'] as int? ?? 0,
        percent: json['progress_percent'] as int? ?? 0,
        stars: json['total_stars'] as int? ?? 0,
        history: (json['recent_history'] as List? ?? const [])
            .map(
              (item) => PracticeHistory.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}
