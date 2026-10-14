class EmotionResult {
  const EmotionResult({required this.emotion, required this.confidence});

  final String emotion;
  final double confidence;

  factory EmotionResult.fromJson(Map<String, dynamic> json) => EmotionResult(
    emotion: json['emotion'] as String? ?? 'neutral',
    confidence: (json['confidence'] as num? ?? 0).toDouble(),
  );
}
