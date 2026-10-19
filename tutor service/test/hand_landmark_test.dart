import 'package:flutter_test/flutter_test.dart';
import 'package:adaptive_sign_language_tutor/data/models/hand_landmark.dart';

void main() {
  const landmark = {'id': 0, 'x': 0.1, 'y': 0.2, 'z': 0.3};

  test('parses legacy top-level landmarks', () {
    final frame = HandFrame.fromJson({
      'frameIndex': 0,
      'timestampMs': 0.0,
      'landmarks': [landmark],
    });

    expect(frame.landmarks, hasLength(1));
    expect(frame.landmarks.single.id, 0);
  });

  test('parses landmarks nested inside hands', () {
    final frame = HandFrame.fromJson({
      'frameIndex': 0,
      'timestampMs': 0.0,
      'hands': [
        {
          'handLabel': 'Left',
          'landmarks': [landmark],
        },
      ],
    });

    expect(frame.landmarks, hasLength(1));
    expect(frame.landmarks.single.id, 0);
  });

  test('preserves all hands from nested gesture frames', () {
    final frame = HandFrame.fromJson({
      'frameIndex': 0,
      'timestampMs': 0.0,
      'hands': [
        {
          'handLabel': 'Left',
          'landmarks': [landmark],
        },
        {
          'handLabel': 'Right',
          'landmarks': [
            {'id': 1, 'x': 0.4, 'y': 0.5, 'z': 0.6},
          ],
        },
      ],
    });

    expect(frame.hands, hasLength(2));
    expect(frame.hands[1].single.id, 1);
  });

  test('keeps frames with no detected landmarks empty', () {
    final frame = HandFrame.fromJson({
      'frameIndex': 0,
      'timestampMs': 0.0,
      'landmarks': [],
    });

    expect(frame.landmarks, isEmpty);
  });
}
