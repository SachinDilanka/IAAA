import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class LandmarkPoint {
  final int id;
  final double x;
  final double y;
  final double z;

  LandmarkPoint({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
  });

  factory LandmarkPoint.fromJson(Map<String, dynamic> json) {
    return LandmarkPoint(
      id: json['id'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
    );
  }
}

class GestureFrame {
  final int frameIndex;
  final double timestampMs;
  final List<LandmarkPoint> landmarks;
  final List<List<LandmarkPoint>> hands;

  GestureFrame({
    required this.frameIndex,
    required this.timestampMs,
    required this.landmarks,
    List<List<LandmarkPoint>>? hands,
  }) : hands = hands ?? (landmarks.isEmpty ? [] : [landmarks]);

  factory GestureFrame.fromJson(Map<String, dynamic> json) {
    final rawHands = json['hands'] as List<dynamic>?;
    final parsedHands = rawHands?.map((rawHand) {
          final hand = Map<String, dynamic>.from(rawHand as Map);
          final rawLandmarks = hand['landmarks'] as List<dynamic>? ?? [];
          return rawLandmarks
              .map(
                (item) => LandmarkPoint.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
        }).toList() ??
        <List<LandmarkPoint>>[];

    final rawLandmarks = json['landmarks'] as List<dynamic>? ?? [];
    final parsedLandmarks = rawLandmarks
        .map(
          (item) =>
              LandmarkPoint.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    final frameHands = parsedHands.isNotEmpty
        ? parsedHands
        : parsedLandmarks.isNotEmpty
            ? [parsedLandmarks]
            : <List<LandmarkPoint>>[];

    return GestureFrame(
      frameIndex: json['frameIndex'] as int,
      timestampMs: (json['timestampMs'] as num).toDouble(),
      landmarks: parsedLandmarks.isNotEmpty
          ? parsedLandmarks
          : frameHands.isEmpty
              ? <LandmarkPoint>[]
              : frameHands.first,
      hands: frameHands,
    );
  }
}

class GestureMatchResult {
  final double overallAccuracy; // 0.0 to 100.0%
  final List<int> errorJointIds; // IDs of joints that exceed error tolerance

  GestureMatchResult({
    required this.overallAccuracy,
    required this.errorJointIds,
  });
}

/// Buffer to maintain a trailing history of tracked live frames
class LiveFrameBuffer {
  final List<List<List<LandmarkPoint>>> frameHistory = [];
  final int maxHistoryLength = 45; // ~1.5s at 30 FPS

  void addFrame(List<List<LandmarkPoint>> trackedHands) {
    if (frameHistory.length >= maxHistoryLength) {
      frameHistory.removeAt(0);
    }
    frameHistory.add(trackedHands);
  }

  void clear() => frameHistory.clear();
}

class GestureMatcherService {
  final Map<String, List<GestureFrame>> _loadedReferenceCache = {};

  /// Load an extracted gesture sequence (e.g. "dataset/landmarks/month/january/january.json").
  Future<List<GestureFrame>> loadReferenceGesture(String assetPath) async {
    if (_loadedReferenceCache.containsKey(assetPath)) {
      return _loadedReferenceCache[assetPath]!;
    }

    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> rawList = json.decode(jsonString);
      final frames =
          rawList.map((item) => GestureFrame.fromJson(item)).toList();
      _loadedReferenceCache[assetPath] = frames;
      return frames;
    } catch (e) {
      print('Error loading reference gesture JSON ($assetPath): $e');
      return [];
    }
  }

  /// Normalize landmarks relative to Wrist (id: 0) and Hand Scale
  List<LandmarkPoint> _normalizeLandmarks(List<LandmarkPoint> landmarks) {
    if (landmarks.isEmpty) return [];

    final wrist = landmarks.firstWhere(
      (lm) => lm.id == 0,
      orElse: () => landmarks.first,
    );

    List<LandmarkPoint> centered = landmarks.map((lm) {
      return LandmarkPoint(
        id: lm.id,
        x: lm.x - wrist.x,
        y: lm.y - wrist.y,
        z: lm.z - wrist.z,
      );
    }).toList();

    final middleMcp = centered.firstWhere(
      (lm) => lm.id == 9,
      orElse: () => centered.first,
    );

    double scale = sqrt(
      middleMcp.x * middleMcp.x +
          middleMcp.y * middleMcp.y +
          middleMcp.z * middleMcp.z,
    );

    if (scale == 0) scale = 1.0;

    return centered.map((lm) {
      return LandmarkPoint(
        id: lm.id,
        x: lm.x / scale,
        y: lm.y / scale,
        z: lm.z / scale,
      );
    }).toList();
  }

  /// Compare single hand landmarks with relative normalization
  GestureMatchResult evaluateGesture(
    List<LandmarkPoint> liveLandmarks,
    List<LandmarkPoint> targetReferenceLandmarks, {
    double toleranceThreshold = 0.35,
  }) {
    if (liveLandmarks.isEmpty || targetReferenceLandmarks.isEmpty) {
      return GestureMatchResult(overallAccuracy: 0.0, errorJointIds: []);
    }

    final normLive = _normalizeLandmarks(liveLandmarks);
    final normRef = _normalizeLandmarks(targetReferenceLandmarks);

    double totalErrorDistance = 0.0;
    List<int> faultyJoints = [];

    int jointCount = min(normLive.length, normRef.length);

    for (int i = 0; i < jointCount; i++) {
      final live = normLive[i];
      final ref = normRef[i];

      double dx = live.x - ref.x;
      double dy = live.y - ref.y;
      double dz = live.z - ref.z;
      double dist = sqrt(dx * dx + dy * dy + dz * dz);

      totalErrorDistance += dist;

      if (dist > toleranceThreshold) {
        faultyJoints.add(live.id);
      }
    }

    double avgError = totalErrorDistance / jointCount;
    double accuracy = max(0.0, min(100.0, (1.0 - (avgError / 0.50)) * 100.0));

    return GestureMatchResult(
      overallAccuracy: double.parse(accuracy.toStringAsFixed(1)),
      errorJointIds: faultyJoints,
    );
  }

  /// Compare live hands against corresponding hands in a reference frame
  GestureMatchResult evaluateMultiHandGesture(
    List<List<LandmarkPoint>> liveHands,
    GestureFrame targetReferenceFrame, {
    double toleranceThreshold = 0.35,
  }) {
    final referenceHands = targetReferenceFrame.hands;
    if (liveHands.isEmpty || referenceHands.isEmpty) {
      return GestureMatchResult(overallAccuracy: 0.0, errorJointIds: []);
    }

    List<int> errorJointIds = [];
    double totalScore = 0.0;

    for (int i = 0; i < referenceHands.length; i++) {
      final refHand = referenceHands[i];

      double bestHandScore = 0.0;
      List<int> bestHandFaults = [];

      for (final liveHand in liveHands) {
        final result = evaluateGesture(
          liveHand,
          refHand,
          toleranceThreshold: toleranceThreshold,
        );
        if (result.overallAccuracy > bestHandScore) {
          bestHandScore = result.overallAccuracy;
          bestHandFaults = result.errorJointIds;
        }
      }

      totalScore += bestHandScore;
      errorJointIds.addAll(bestHandFaults);
    }

    double finalAccuracy = totalScore / referenceHands.length;

    return GestureMatchResult(
      overallAccuracy: double.parse(finalAccuracy.toStringAsFixed(1)),
      errorJointIds: errorJointIds.toSet().toList(),
    );
  }

  /// Matches a held static sign against the captured examples for that sign.
  GestureMatchResult evaluateBestStaticMatch(
    List<List<LandmarkPoint>> liveHands,
    List<GestureFrame> referenceFrames,
  ) {
    if (liveHands.isEmpty || referenceFrames.isEmpty) {
      return GestureMatchResult(overallAccuracy: 0.0, errorJointIds: []);
    }

    GestureMatchResult? bestMatch;
    for (final frame in referenceFrames) {
      if (frame.hands.isEmpty) continue;
      final result = evaluateMultiHandGesture(liveHands, frame);
      if (bestMatch == null ||
          result.overallAccuracy > bestMatch.overallAccuracy) {
        bestMatch = result;
      }
    }

    return bestMatch ??
        GestureMatchResult(overallAccuracy: 0.0, errorJointIds: []);
  }

  /// Evaluates dynamic sequence/trajectory match across time for Month signs
  double evaluateSequenceMatch(
    List<List<List<LandmarkPoint>>> liveBuffer,
    List<GestureFrame> referenceSequence,
  ) {
    if (liveBuffer.length < 5 || referenceSequence.isEmpty) return 0.0;

    int step = max(1, (referenceSequence.length / 10).floor());
    List<GestureFrame> keyFrames = [];
    for (int i = 0; i < referenceSequence.length; i += step) {
      keyFrames.add(referenceSequence[i]);
    }

    double totalMatchedScore = 0.0;

    for (var keyFrame in keyFrames) {
      double bestFrameScore = 0.0;

      for (var liveFrameHands in liveBuffer) {
        final result = evaluateMultiHandGesture(liveFrameHands, keyFrame);
        if (result.overallAccuracy > bestFrameScore) {
          bestFrameScore = result.overallAccuracy;
        }
      }

      totalMatchedScore += bestFrameScore;
    }

    double finalScore = totalMatchedScore / keyFrames.length;
    return double.parse(finalScore.toStringAsFixed(1));
  }
}