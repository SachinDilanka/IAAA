import 'dart:convert';

enum ExerciseCategory { letter, word }

class Exercise {
  const Exercise({
    required this.id,
    required this.category,
    required this.sinhalaText,
    required this.steps,
    required this.sinhalaInstruction,
    required this.emoji,
    required this.difficulty,
  });

  final int id;
  final ExerciseCategory category;
  final String sinhalaText;
  final List<String> steps;
  final String sinhalaInstruction;
  final String emoji;
  final int difficulty;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    final rawSteps = jsonDecode(json['breakdown_json'] as String? ?? '[]');
    return Exercise(
      id: json['id'] as int,
      category: json['category'] == 'word'
          ? ExerciseCategory.word
          : ExerciseCategory.letter,
      sinhalaText: json['sinhala_text'] as String,
      steps: List<String>.from(rawSteps as List),
      sinhalaInstruction: json['instruction_sinhala'] as String,
      emoji: json['icon_emoji'] as String? ?? '⭐',
      difficulty: json['difficulty_level'] as int? ?? 1,
    );
  }
}
