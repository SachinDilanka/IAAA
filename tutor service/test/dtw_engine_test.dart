import 'package:adaptive_sign_language_tutor/core/utils/dtw_engine.dart';
import 'package:adaptive_sign_language_tutor/data/models/hand_landmark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identical one-hand gesture scores 100 percent', () {
    final frame = _frame([_hand()]);

    final result = DTWEngine.evaluateGestureSequence([frame], [frame]);

    expect(result.accuracyScore, 100);
    expect(result.isTrajectoryValid, isTrue);
  });

  test('scores every hand and penalizes a missing hand', () {
    final hand = _hand();
    final referenceFrame = _frame([hand, _hand(offset: 0.5)]);
    final liveFrame = _frame([hand]);

    final result = DTWEngine.evaluateGestureSequence(
      [liveFrame],
      [referenceFrame],
    );

    expect(result.accuracyScore, 50);
  });

  test('normalizes both hands for translation and scale', () {
    final referenceFrame = _frame([_hand(), _hand(offset: 0.5)]);
    final translatedScaledFrame = _frame([
      _hand(offset: 2, scale: 2),
      _hand(offset: 3, scale: 2),
    ]);

    final result = DTWEngine.evaluateGestureSequence(
      [translatedScaledFrame],
      [referenceFrame],
    );

    expect(result.accuracyScore, closeTo(100, 0.001));
  });

  test('scores relative hand position as part of a two-hand sign', () {
    final referenceFrame = _frame([_hand(), _hand(offset: 0.5)]);
    final liveFrame = _frame([_hand(), _hand(offset: 0.53)]);

    final result = DTWEngine.evaluateGestureSequence(
      [liveFrame],
      [referenceFrame],
    );

    expect(result.accuracyScore, lessThan(100));
  });
}

HandFrame _frame(List<List<HandLandmark>> hands) => HandFrame(
  frameIndex: 0,
  timestampMs: 0,
  landmarks: hands.first,
  hands: hands,
);

List<HandLandmark> _hand({double offset = 0, double scale = 1}) {
  return List.generate(21, (id) {
    return HandLandmark(
      id: id,
      x: offset + scale * (0.1 + (id % 5) * 0.03),
      y: offset + scale * (0.2 + (id ~/ 5) * 0.03),
      z: scale * id * -0.001,
    );
  });
}
