import 'dart:math';

import '../../data/models/hand_landmark.dart';

/// Evaluation result containing overall gesture accuracy score and specific joint error IDs
class GestureEvaluationResult {
  final double accuracyScore; // Percentage score (0.0 to 100.0%)
  final double dtwDistance; // Raw Dynamic Time Warping alignment distance
  final List<int>
  errorJointIds; // List of landmark IDs exceeding error tolerance threshold
  final bool isTrajectoryValid;

  GestureEvaluationResult({
    required this.accuracyScore,
    required this.dtwDistance,
    required this.errorJointIds,
    required this.isTrajectoryValid,
  });
}

class DTWEngine {
  // Deviation tolerance threshold in normalized spatial distance
  static const double spatialErrorThreshold = 0.35;

  /// Calculates spatial frame distance between a live hand frame and a reference hand frame
  static double calculateFrameDistance(
    HandFrame liveFrame,
    HandFrame refFrame,
    List<int> outErrorJoints,
  ) {
    outErrorJoints.clear();

    final handCount = max(liveFrame.hands.length, refFrame.hands.length);
    if (handCount == 0) return 1.0;

    var totalHandDistance = 0.0;
    for (var handIndex = 0; handIndex < handCount; handIndex++) {
      if (handIndex >= liveFrame.hands.length) {
        outErrorJoints.addAll(
          refFrame.hands[handIndex].map((landmark) => landmark.id),
        );
        totalHandDistance += 1.0;
        continue;
      }
      if (handIndex >= refFrame.hands.length) {
        outErrorJoints.addAll(
          liveFrame.hands[handIndex].map((landmark) => landmark.id),
        );
        totalHandDistance += 1.0;
        continue;
      }

      final liveHand = liveFrame.hands[handIndex];
      final refMap = {
        for (final landmark in refFrame.hands[handIndex]) landmark.id: landmark,
      };
      var handDistance = 0.0;
      var comparedLandmarkCount = 0;
      for (final liveLandmark in liveHand) {
        final refLandmark = refMap[liveLandmark.id];
        if (refLandmark == null) continue;

        final distance = liveLandmark.distanceTo(refLandmark);
        handDistance += distance;
        comparedLandmarkCount++;
        if (distance > spatialErrorThreshold) {
          outErrorJoints.add(liveLandmark.id);
        }
      }

      if (comparedLandmarkCount == 0) {
        outErrorJoints.addAll(liveHand.map((landmark) => landmark.id));
        totalHandDistance += 1.0;
      } else {
        totalHandDistance += handDistance / comparedLandmarkCount;
      }
    }

    return totalHandDistance / handCount;
  }

  /// Evaluates live frame sequence against reference sequence using Dynamic Time Warping (DTW)
  static GestureEvaluationResult evaluateGestureSequence(
    List<HandFrame> liveSequence,
    List<HandFrame> referenceSequence,
  ) {
    if (liveSequence.isEmpty || referenceSequence.isEmpty) {
      return GestureEvaluationResult(
        accuracyScore: 0.0,
        dtwDistance: double.infinity,
        errorJointIds: [],
        isTrajectoryValid: false,
      );
    }

    // Normalize all input sequences to achieve translation & scale invariance
    final normLive = liveSequence.map((f) => f.normalize()).toList();
    final normRef = referenceSequence.map((f) => f.normalize()).toList();

    final n = normLive.length;
    final m = normRef.length;

    // Initialize DTW Cost Matrix
    List<List<double>> dtwMatrix = List.generate(
      n + 1,
      (_) => List.filled(m + 1, double.infinity),
    );
    dtwMatrix[0][0] = 0.0;
    final pathLengths = List.generate(n + 1, (_) => List.filled(m + 1, 0));

    List<int> currentErrorJoints = [];
    Set<int> accumulatedErrorJoints = {};

    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        double cost = calculateFrameDistance(
          normLive[i - 1],
          normRef[j - 1],
          currentErrorJoints,
        );

        // Accumulate flagged joints for real-time visual feedback overlays
        if (i == n || cost > spatialErrorThreshold * 10) {
          accumulatedErrorJoints.addAll(currentErrorJoints);
        }

        var previousRow = i - 1;
        var previousColumn = j;
        var minPreviousCost = dtwMatrix[previousRow][previousColumn];
        if (dtwMatrix[i][j - 1] < minPreviousCost) {
          previousRow = i;
          previousColumn = j - 1;
          minPreviousCost = dtwMatrix[previousRow][previousColumn];
        }
        if (dtwMatrix[i - 1][j - 1] < minPreviousCost) {
          previousRow = i - 1;
          previousColumn = j - 1;
          minPreviousCost = dtwMatrix[previousRow][previousColumn];
        }

        dtwMatrix[i][j] = cost + minPreviousCost;
        pathLengths[i][j] = pathLengths[previousRow][previousColumn] + 1;
      }
    }

    final finalDtwDistance = dtwMatrix[n][m] / max(1, pathLengths[n][m]);

    // Score the average landmark deviation, rather than the sum across all joints.
    final accuracy = max(0.0, min(100.0, 100.0 - finalDtwDistance * 100.0));

    return GestureEvaluationResult(
      accuracyScore: accuracy,
      dtwDistance: finalDtwDistance,
      errorJointIds: accumulatedErrorJoints.toList(),
      isTrajectoryValid: accuracy >= 70.0,
    );
  }
}
