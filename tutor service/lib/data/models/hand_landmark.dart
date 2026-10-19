import 'dart:math';

/// Represents a single 3D joint landmark coordinate (X, Y, Z) extracted from camera frames
class HandLandmark {
  final int id; // 0 to 20 matching MediaPipe landmark indices
  final double x;
  final double y;
  final double z;

  HandLandmark({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
  });

  factory HandLandmark.fromJson(Map<String, dynamic> json) {
    return HandLandmark(
      id: json['id'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
    );
  }


  Map<String, dynamic> toJson() => {'id': id, 'x': x, 'y': y, 'z': z};

  /// Calculates Euclidean distance between this landmark and another landmark in 3D space
  double distanceTo(HandLandmark other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }
}

/// Represents a full hand frame containing all 21 keypoint landmarks at a specific timestamp
class HandFrame {
  final int frameIndex;
  final double timestampMs;
  final List<HandLandmark> landmarks;
  final List<List<HandLandmark>> hands;

  HandFrame({
    required this.frameIndex,
    required this.timestampMs,
    required List<HandLandmark> landmarks,
    List<List<HandLandmark>>? hands,
  }) : landmarks = landmarks.isNotEmpty
           ? landmarks
           : hands != null && hands.isNotEmpty
           ? hands.first
           : const [],
       hands = hands ?? (landmarks.isEmpty ? const [] : [landmarks]);

  factory HandFrame.fromJson(Map<String, dynamic> json) {
    final rawHands = json['hands'] as List<dynamic>? ?? [];
    final parsedHands = rawHands.map((rawHand) {
      final hand = Map<String, dynamic>.from(rawHand as Map);
      final rawLandmarks = hand['landmarks'] as List<dynamic>? ?? [];
      return rawLandmarks.map((i) => HandLandmark.fromJson(i)).toList();
    }).toList();
    final rawLandmarks = json['landmarks'] as List<dynamic>? ?? [];
    final parsedLandmarks = rawLandmarks
        .map((i) => HandLandmark.fromJson(i))
        .toList();
    final frameHands = parsedHands.isNotEmpty
        ? parsedHands
        : parsedLandmarks.isNotEmpty
        ? [parsedLandmarks]
        : <List<HandLandmark>>[];

    return HandFrame(
      frameIndex: json['frameIndex'] as int,
      timestampMs: (json['timestampMs'] as num).toDouble(),
      landmarks: parsedLandmarks.isNotEmpty
          ? parsedLandmarks
          : frameHands.isEmpty
          ? const []
          : frameHands.first,
      hands: frameHands,
    );
  }

  Map<String, dynamic> toJson() => {
    'frameIndex': frameIndex,
    'timestampMs': timestampMs,
    'landmarks': landmarks.map((l) => l.toJson()).toList(),
    'hands': hands
        .map((hand) => {'landmarks': hand.map((l) => l.toJson()).toList()})
        .toList(),
  };

  /// Normalizes hand coordinates:
  /// 1. Wrist Translation: Sets Wrist (id: 0) as origin (0, 0, 0)
  /// 2. Scale Invariance: Scales all coordinates by palm size (Wrist to Middle Finger MCP)
  HandFrame normalize() {
    if (hands.isEmpty) return this;

    final anchorHand = hands.firstWhere(
      (hand) => hand.isNotEmpty,
      orElse: () => const [],
    );
    if (anchorHand.isEmpty) return this;

    final wrist = anchorHand.firstWhere(
      (landmark) => landmark.id == 0,
      orElse: () => HandLandmark(id: 0, x: 0, y: 0, z: 0),
    );
    final middleMcp = anchorHand.firstWhere(
      (landmark) => landmark.id == 9,
      orElse: () => HandLandmark(id: 9, x: 0, y: 1, z: 0),
    );
    final scaleFactor = wrist.distanceTo(middleMcp);
    final validScale = scaleFactor > 0.0001 ? scaleFactor : 1.0;

    final normalizedHands = hands.map((hand) {
      return hand.map((landmark) {
        return HandLandmark(
          id: landmark.id,
          x: (landmark.x - wrist.x) / validScale,
          y: (landmark.y - wrist.y) / validScale,
          z: (landmark.z - wrist.z) / validScale,
        );
      }).toList();
    }).toList();
    return HandFrame(
      frameIndex: frameIndex,
      timestampMs: timestampMs,
      landmarks: normalizedHands.first,
      hands: normalizedHands,
    );
  }
}
