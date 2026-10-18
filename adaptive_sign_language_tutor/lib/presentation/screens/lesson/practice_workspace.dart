import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/utils/dtw_engine.dart';
import '../../../core/utils/gesture_asset_paths.dart';
import '../../../data/models/hand_landmark.dart';
import '../../widgets/avatar_viewer.dart';
import '../../widgets/camera_view.dart';

class PracticeWorkspaceScreen extends StatefulWidget {
  final int? lessonId;
  final String lessonTitle;
  final String? referenceAssetPath;

  const PracticeWorkspaceScreen({
    Key? key,
    required this.lessonId,
    required this.lessonTitle,
    this.referenceAssetPath,
  }) : super(key: key);

  @override
  _PracticeWorkspaceScreenState createState() =>
      _PracticeWorkspaceScreenState();
}

class _PracticeWorkspaceScreenState extends State<PracticeWorkspaceScreen> {
  List<HandFrame> _referenceSequence = [];
  List<HandFrame> _liveSequence = [];
  List<HandLandmark> _currentLandmarks = [];
  List<int> _currentErrorJoints = [];

  double? _currentAccuracy;
  bool _isEvaluating = false;
  bool _isReferenceLoading = false;
  String? _referenceLoadError;
  double _playbackSpeed = 1.0;
  bool _hasSeenHands = false;
  bool _attemptSubmitted = false;
  int _attemptId = 0;
  Timer? _handsAwayTimer;

  @override
  void initState() {
    super.initState();
    if (widget.referenceAssetPath == null) {
      _referenceLoadError =
          'No captured reference is available for this letter. '
          'Hand tracking is available, but accuracy scoring is not.';
    } else {
      _isReferenceLoading = true;
      _loadReferenceGestureData();
    }
  }

  Future<void> _loadReferenceGestureData() async {
    try {
      final jsonString = await rootBundle.loadString(
        widget.referenceAssetPath!,
      );
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final sequence = jsonList
          .map((item) => HandFrame.fromJson(item as Map<String, dynamic>))
          .where((frame) => frame.hands.any((hand) => hand.isNotEmpty))
          .toList();

      if (!mounted) return;
      setState(() {
        _referenceSequence = sequence;
        _isReferenceLoading = false;
        if (sequence.isEmpty) {
          _referenceLoadError =
              'This letter has no usable captured reference frames.';
        }
      });
    } catch (e) {
      debugPrint('Failed to load gesture reference: $e');
      if (!mounted) return;
      setState(() {
        _referenceSequence = [];
        _isReferenceLoading = false;
        _referenceLoadError = 'The gesture reference could not be loaded.';
      });
    }
  }

  /// Triggered whenever real MediaPipe model yields joint coordinates
  void _onFrameCaptured(List<List<HandLandmark>> hands) {
    if (_isEvaluating || _attemptSubmitted) return;

    final detectedHands = hands.where((hand) => hand.isNotEmpty).toList();
    if (detectedHands.isEmpty) {
      if (_currentLandmarks.isNotEmpty && mounted) {
        setState(() => _currentLandmarks = []);
      }
      if (_hasSeenHands && !_isEvaluating && _handsAwayTimer == null) {
        _handsAwayTimer = Timer(const Duration(milliseconds: 1200), () {
          _handsAwayTimer = null;
          if (mounted && _liveSequence.isNotEmpty) {
            _submitAttempt();
          }
        });
      }
      return;
    }

    _handsAwayTimer?.cancel();
    _handsAwayTimer = null;
    _hasSeenHands = true;
    final landmarks = detectedHands.first;
    setState(() {
      _currentLandmarks = landmarks;
    });

    _liveSequence.add(
      HandFrame(
        frameIndex: _liveSequence.length,
        timestampMs: DateTime.now().millisecondsSinceEpoch.toDouble(),
        landmarks: landmarks,
        hands: detectedHands,
      ),
    );

    if (_liveSequence.length % 5 == 0 &&
        _referenceSequence.length <= 5 &&
        _referenceSequence.isNotEmpty) {
      final result = DTWEngine.evaluateGestureSequence(
        _liveSequence,
        _referenceSequence,
      );

      setState(() {
        _currentErrorJoints = result.errorJointIds;
      });
    }
  }

  void _onCameraAccuracyChanged(double accuracy) {
    if (!mounted || _attemptSubmitted) return;
    setState(() => _currentAccuracy = accuracy);
  }

  Future<void> _submitAttempt() async {
    if (_isEvaluating || _referenceSequence.isEmpty || _liveSequence.isEmpty) {
      return;
    }
    _handsAwayTimer?.cancel();
    _handsAwayTimer = null;
    _attemptSubmitted = true;
    _hasSeenHands = false;
    setState(() => _isEvaluating = true);

    final finalResult = DTWEngine.evaluateGestureSequence(
      _liveSequence,
      _referenceSequence,
    );
    final score = _currentAccuracy ?? finalResult.accuracyScore;

    try {
      final lessonId =
          widget.lessonId ??
          await DatabaseHelper.instance.getOrCreateLessonId(
            title: widget.lessonTitle,
            category:
                widget.referenceAssetPath != null &&
                    GestureAssetPaths.isVerbAsset(widget.referenceAssetPath!)
                ? 'Verbs'
                : DatabaseHelper.isMonthTitle(widget.lessonTitle)
                ? 'Months'
                : 'Alphabet',
          );
      await DatabaseHelper.instance.logPracticeSession(
        lessonId: lessonId,
        lessonTitle: widget.lessonTitle,
        dtwAccuracyScore: score,
        executionTimeMs: 1200,
        commonErrorJoints: finalResult.errorJointIds.join(','),
      );
    } catch (error) {
      debugPrint('Failed to save gesture practice result: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your practice result.')),
        );
      }
      _attemptSubmitted = false;
      if (mounted) setState(() => _isEvaluating = false);
      return;
    }

    if (!mounted) return;
    setState(() => _isEvaluating = false);
    _showResultDialog(score);
  }

  @override
  void dispose() {
    _handsAwayTimer?.cancel();
    super.dispose();
  }

  void _showResultDialog(double score) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          score >= 70.0 ? 'Great Job! 🎉' : 'Keep Practicing! 💪',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gesture Accuracy',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              '${score.toInt()}%',
              style: GoogleFonts.poppins(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: score >= 70.0 ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _liveSequence.clear();
                _currentAccuracy = null;
                _currentErrorJoints.clear();
                _currentLandmarks.clear();
                _hasSeenHands = false;
                _attemptSubmitted = false;
                _attemptId++;
              });
            },
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.lessonTitle,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          if (_isReferenceLoading) const LinearProgressIndicator(minHeight: 2),
          if (!_isReferenceLoading && _referenceLoadError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Text(
                _referenceLoadError!,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
              ),
            ),
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Stack(
                children: [
                  Avatar3DViewerWidget(
                    modelPath: 'assets/models/avatar_signs.glb',
                    referenceAssetPath: widget.referenceAssetPath,
                    playbackSpeed: _playbackSpeed,
                    onPlaybackSpeedChanged: (speed) =>
                        setState(() => _playbackSpeed = speed),
                    label: widget.lessonTitle,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CameraViewWidget(
                currentLandmarks: _currentLandmarks,
                currentAccuracy: _currentAccuracy,
                errorJointIds: _currentErrorJoints,
                onFrameCaptured: _onFrameCaptured,
                referenceAssetPath: widget.referenceAssetPath,
                onAccuracyChanged: _onCameraAccuracyChanged,
                attemptId: _attemptId,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E2230),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Make the sign, then lower both hands to submit automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          _handsAwayTimer?.cancel();
                          setState(() {
                            _liveSequence.clear();
                            _currentAccuracy = null;
                            _currentErrorJoints.clear();
                            _currentLandmarks.clear();
                            _hasSeenHands = false;
                            _attemptSubmitted = false;
                            _attemptId++;
                          });
                        },
                        child: const Text(
                          'Start Over',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed:
                            _isEvaluating ||
                                _referenceSequence.isEmpty ||
                                _liveSequence.isEmpty
                            ? null
                            : _submitAttempt,
                        child: _isEvaluating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit Attempt',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
