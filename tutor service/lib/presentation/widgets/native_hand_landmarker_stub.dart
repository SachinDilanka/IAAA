import 'package:camera/camera.dart';

class Hand {
  final List<Landmark> landmarks;

  Hand(this.landmarks);
}

class Landmark {
  final double x;
  final double y;
  final double z;

  Landmark(this.x, this.y, this.z);
}

enum HandLandmarkerDelegate { cpu, gpu }

class HandLandmarkerPlugin {
  static HandLandmarkerPlugin create({
    int numHands = 2,
    HandLandmarkerDelegate delegate = HandLandmarkerDelegate.gpu,
  }) {
    throw UnsupportedError('Native hand tracking is not available on web.');
  }

  Stream<List<Hand>> get landmarkStream => const Stream.empty();

  void processFrame(CameraImage image, int sensorOrientation) {}

  void dispose() {}
}
