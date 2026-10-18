import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart'
    if (dart.library.html) 'native_hand_landmarker_stub.dart' as hand_tracking;

import 'package:adaptive_sign_language_tutor/core/services/gesture_matcher.dart';

import '../../../core/utils/gesture_asset_paths.dart';
import '../../../core/utils/web_tracking.dart';
import '../../data/models/hand_landmark.dart';
import 'camera_preview_platform.dart' as web_preview;

class CameraViewWidget extends StatefulWidget {
  final List<HandLandmark> currentLandmarks;
  final double? currentAccuracy;
  final List<int> errorJointIds;
  final Function(List<List<HandLandmark>>) onFrameCaptured;
  final String? referenceAssetPath;
  final ValueChanged<double>? onAccuracyChanged;
  final int attemptId;

  const CameraViewWidget({
    Key? key,
    required this.currentLandmarks,
    required this.currentAccuracy,
    required this.errorJointIds,
    required this.onFrameCaptured,
    required this.referenceAssetPath,
    required this.onAccuracyChanged,
    required this.attemptId,
  }) : super(key: key);

  @override
  _CameraViewWidgetState createState() => _CameraViewWidgetState();
}

class _CameraViewWidgetState extends State<CameraViewWidget> {
  CameraController? _controller;
  hand_tracking.HandLandmarkerPlugin? _handLandmarker;
  StreamSubscription<List<hand_tracking.Hand>>? _landmarkSubscription;
  bool _isInitialized = false;
  List<List<HandLandmark>> _trackedHands = [];
  String? _trackingError;
  bool _hasReportedFrameError = false;

  // --- Dynamic & Multi-Hand Gesture Engine ---
  final GestureMatcherService _gestureMatcher = GestureMatcherService();
  final LiveFrameBuffer _liveBuffer = LiveFrameBuffer();
  List<GestureFrame> _referenceSequence = [];
  double _calculatedAccuracy = 0.0;
  List<int> _highlightErrorJoints = [];

  @override
  void initState() {
    super.initState();
    final referenceAssetPath = widget.referenceAssetPath;
    if (referenceAssetPath != null) {
      _loadReferenceGesture(referenceAssetPath);
    }

    if (kIsWeb) {
      _setupWebTracking();
    } else {
      _initializeNativeCamera();
    }
  }

  @override
  void didUpdateWidget(covariant CameraViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attemptId != widget.attemptId) {
      _liveBuffer.clear();
      _calculatedAccuracy = 0.0;
      _highlightErrorJoints = [];
    }
    if (oldWidget.referenceAssetPath != widget.referenceAssetPath) {
      _liveBuffer.clear();
      _referenceSequence = [];
      final referenceAssetPath = widget.referenceAssetPath;
      if (referenceAssetPath != null) {
        _loadReferenceGesture(referenceAssetPath);
      }
    }
  }

  /// Load target gesture dataset from JSON
  Future<void> _loadReferenceGesture(String jsonAssetPath) async {
    final frames = await _gestureMatcher.loadReferenceGesture(jsonAssetPath);
    if (frames.isNotEmpty && mounted) {
      setState(() {
        _referenceSequence = frames;
      });
    }
  }

  /// Evaluate live hands against target sequence or frame
  void _evaluateLiveHands(List<List<HandLandmark>> trackedHands) {
    if (trackedHands.isEmpty) return;

    List<List<LandmarkPoint>> liveHands = trackedHands.map((hand) {
      return hand
          .map((lm) => LandmarkPoint(id: lm.id, x: lm.x, y: lm.y, z: lm.z))
          .toList();
    }).toList();

    _liveBuffer.addFrame(liveHands);

    double score = 0.0;
    List<int> errors = [];
    final isDynamicGesture =
        widget.referenceAssetPath != null &&
        GestureAssetPaths.isDynamicAsset(widget.referenceAssetPath!);

    if (isDynamicGesture) {
      score = _gestureMatcher.evaluateSequenceMatch(
        _liveBuffer.frameHistory,
        _referenceSequence,
      );
    } else if (_referenceSequence.isNotEmpty) {
      final result = _gestureMatcher.evaluateBestStaticMatch(
        liveHands,
        _referenceSequence,
      );
      score = result.overallAccuracy;
      errors = result.errorJointIds;
    }

    if (mounted) {
      setState(() {
        _calculatedAccuracy = score;
        _highlightErrorJoints = errors;
      });
      widget.onAccuracyChanged?.call(score);
    }
  }

  void _setupWebTracking() {
    WebTrackingHelper.registerHandTrackingListener((jsonString) {
      if (jsonString.isEmpty) return;

      Map<String, dynamic> data;
      try {
        data = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Failed to parse web tracking data: $e');
        return;
      }

      final hands = (data['hands'] as List<dynamic>? ?? [])
          .map(
            (hand) => (hand as List<dynamic>)
                .map(
                  (item) => HandLandmark.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList(),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _trackedHands = hands;
        _trackingError = data['error'] as String?;
        _isInitialized = true;
      });

      _evaluateLiveHands(hands);
      widget.onFrameCaptured(hands);
    });

    _isInitialized = true;

    void startBridge() {
      if (!mounted) return;
      WebTrackingHelper.initMediaPipe();
    }

    startBridge();
  }

  Future<void> _initializeNativeCamera() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      setState(() {
        _trackingError = 'Hand tracking is currently supported on Android and web.';
      });
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No cameras are available on this device.');
      }
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (!mounted) return;

      if (defaultTargetPlatform == TargetPlatform.android) {
        _handLandmarker = hand_tracking.HandLandmarkerPlugin.create(
          numHands: 2,
          delegate: hand_tracking.HandLandmarkerDelegate.cpu,
        );
        _landmarkSubscription = _handLandmarker!.landmarkStream.listen(
          _onNativeLandmarks,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Native hand tracking stream failed: $error');
            if (mounted) {
              setState(() {
                _trackingError = 'Hand tracking failed. Restart the practice screen.';
              });
            }
          },
        );
      }

      await _controller!.startImageStream(_processNativeImageFrame);
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
    } catch (error, stackTrace) {
      debugPrint('Native camera or hand tracking initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _trackingError = 'Camera or hand tracking could not start: $error';
        });
      }
    }
  }

  void _processNativeImageFrame(CameraImage image) {
    final landmarker = _handLandmarker;
    final controller = _controller;
    if (landmarker == null || controller == null) return;

    try {
      landmarker.processFrame(image, controller.description.sensorOrientation);
    } catch (error) {
      if (_hasReportedFrameError) return;
      _hasReportedFrameError = true;
      debugPrint('Failed to process camera frame for hand tracking: $error');
      if (mounted) {
        setState(() {
          _trackingError = 'Camera frames could not be processed for hand tracking.';
        });
      }
    }
  }

  void _onNativeLandmarks(List<hand_tracking.Hand> detectedHands) {
    final hands = detectedHands
        .map(
          (hand) => hand.landmarks
              .asMap()
              .entries
              .map(
                (entry) => HandLandmark(
                  id: entry.key,
                  x: entry.value.x,
                  y: entry.value.y,
                  z: entry.value.z,
                ),
              )
              .toList(),
        )
        .where((hand) => hand.isNotEmpty)
        .toList();
    if (!mounted) return;
    setState(() {
      _trackedHands = hands;
      _trackingError = null;
    });
    _evaluateLiveHands(hands);
    widget.onFrameCaptured(hands);
  }

  @override
  void dispose() {
    if (kIsWeb) {
      WebTrackingHelper.unregisterHandTrackingListener();
      WebTrackingHelper.stopMediaPipe();
    }
    unawaited(_landmarkSubscription?.cancel());
    _handLandmarker?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      final trackingError = _trackingError;
      if (trackingError != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              trackingError,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final hands = kIsWeb
        ? _trackedHands
        : widget.currentLandmarks.isEmpty
        ? <List<HandLandmark>>[]
        : [widget.currentLandmarks];

    final displayAccuracy = widget.currentAccuracy ?? _calculatedAccuracy;
    final combinedErrorJoints = {
      ...widget.errorJointIds,
      ..._highlightErrorJoints,
    }.toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (kIsWeb)
            web_preview.buildCameraPreview()
          else if (_controller != null && _controller!.value.isInitialized)
            CameraPreview(_controller!),
          CustomPaint(
            painter: AROverlayPainter(
              hands: hands,
              errorJointIds: combinedErrorJoints,
              mirrorX: kIsWeb,
            ),
          ),

          // Tracking Indicator
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    color: _trackingError != null
                        ? Colors.redAccent
                        : hands.isNotEmpty
                        ? Colors.greenAccent
                        : Colors.amberAccent,
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _trackingError ??
                        (hands.isEmpty
                            ? 'Searching for hands...'
                            : '${hands.length} hand${hands.length == 1 ? '' : 's'} tracked'),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // Accuracy Badge Overlay
          if (hands.isNotEmpty)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: displayAccuracy >= 80.0
                      ? Colors.green.withOpacity(0.85)
                      : displayAccuracy >= 50.0
                      ? Colors.orangeAccent.withOpacity(0.85)
                      : Colors.redAccent.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Accuracy: ${displayAccuracy.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AROverlayPainter extends CustomPainter {
  final List<List<HandLandmark>> hands;
  final List<int> errorJointIds;
  final bool mirrorX;

  AROverlayPainter({
    required this.hands,
    required this.errorJointIds,
    required this.mirrorX,
  });

  static const List<List<int>> handConnections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [0, 17],
    [17, 18],
    [18, 19],
    [19, 20],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final jointPaint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    final connectionPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.6)
      ..strokeWidth = 3.0;
    final errorPaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    for (final hand in hands) {
      final pointMap = <int, Offset>{
        for (final landmark in hand)
          landmark.id: Offset(
            (mirrorX ? 1 - landmark.x : landmark.x) * size.width,
            landmark.y * size.height,
          ),
      };

      for (final connection in handConnections) {
        final start = pointMap[connection[0]];
        final end = pointMap[connection[1]];
        if (start != null && end != null) {
          canvas.drawLine(start, end, connectionPaint);
        }
      }

      for (final landmark in hand) {
        final isError = errorJointIds.contains(landmark.id);
        canvas.drawCircle(
          pointMap[landmark.id]!,
          isError ? 5.0 : 3.0,
          isError ? errorPaint : jointPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant AROverlayPainter oldDelegate) => true;
}
