import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../core/utils/gesture_asset_paths.dart';
import '../../data/models/hand_landmark.dart';
import 'avatar_animation_dispatcher_stub.dart'
    if (dart.library.js_interop) 'avatar_animation_dispatcher_web.dart'
    as avatar_animation_dispatcher;

class Avatar3DViewerWidget extends StatefulWidget {
  final String modelPath;
  final String? referenceAssetPath;
  final double playbackSpeed;
  final bool isOrbitEnabled;
  final String label;
  final ValueChanged<double>? onPlaybackSpeedChanged;

  const Avatar3DViewerWidget({
    super.key,
    required this.modelPath,
    this.referenceAssetPath,
    this.playbackSpeed = 1.0,
    this.isOrbitEnabled = true,
    this.label = 'SSL Alphabet: Letter A',
    this.onPlaybackSpeedChanged,
  });

  @override
  State<Avatar3DViewerWidget> createState() => _Avatar3DViewerWidgetState();
}

class _Avatar3DViewerWidgetState extends State<Avatar3DViewerWidget> {
  static const _fingerColors = [
    Color(0xFFFF806E),
    Color(0xFFFFB45E),
    Color(0xFFA8E875),
    Color(0xFF51D5E8),
    Color(0xFFC28AFF),
  ];
  static const _fingerNames = ['Thumb', 'Index', 'Middle', 'Ring', 'Pinky'];

  static const _connections = [
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

  List<List<HandLandmark>> _referenceFrames = [];
  int _currentFrameIndex = 0;
  String? _referenceLoadError;
  String? _animationError;
  String? _animationJavascript;
  double _cameraRotationY = 0;
  Timer? _playbackTimer;
  bool _showLandmarkGuide = false;
  bool _animationBridgeReady = false;
  bool _isPlaying = true;
  Future<void> Function(String)? _runViewerJavascript;

  bool get _isDynamicGesture =>
      widget.referenceAssetPath != null &&
      GestureAssetPaths.isDynamicAsset(widget.referenceAssetPath!);

  List<HandLandmark>? get _referenceLandmarks =>
      _referenceFrames.isEmpty ? null : _referenceFrames[_currentFrameIndex];

  @override
  void initState() {
    super.initState();
    _loadAnimationJavascript();
    _loadReferencePose();
  }

  @override
  void didUpdateWidget(covariant Avatar3DViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.referenceAssetPath != widget.referenceAssetPath) {
      _stopPlayback();
      _referenceFrames = [];
      _currentFrameIndex = 0;
      _referenceLoadError = null;
      _sendAnimationCommand();
      _loadReferencePose();
    }
    if (oldWidget.playbackSpeed != widget.playbackSpeed && _isDynamicGesture) {
      if (_showLandmarkGuide &&
          _isPlaying &&
          _playbackTimer != null &&
          _referenceFrames.length > 1) {
        _startPlayback();
      } else if (!_showLandmarkGuide) {
        _sendAnimationCommand();
      }
    }
  }

  Future<void> _loadAnimationJavascript() async {
    try {
      final script = await rootBundle.loadString(
        'assets/js/avatar_animation.js',
      );
      if (!mounted) return;
      setState(() {
        _animationJavascript = script;
        _animationError = null;
      });
      _sendAnimationCommand();
    } on Exception catch (error) {
      debugPrint('Failed to load avatar animation bridge: $error');
      if (!mounted) return;
      setState(() {
        _animationError = 'Avatar animation controls are unavailable.';
      });
    }
  }

  Future<void> _loadReferencePose() async {
    final assetPath = widget.referenceAssetPath;
    if (assetPath == null) {
      setState(() {
        _referenceFrames = [];
        _referenceLoadError = 'No captured reference pose is available.';
      });
      return;
    }

    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final rawFrames = jsonDecode(jsonString) as List<dynamic>;
      final referenceFrames = <List<HandLandmark>>[];
      for (final rawFrame in rawFrames) {
        final frame = HandFrame.fromJson(
          Map<String, dynamic>.from(rawFrame as Map),
        );
        final hand = frame.hands.cast<List<HandLandmark>?>().firstWhere(
          (candidate) => candidate != null && candidate.length == 21,
          orElse: () => null,
        );
        if (hand != null) referenceFrames.add(hand);
      }
      if (referenceFrames.isEmpty) {
        throw const FormatException('No complete 21-point hand pose found.');
      }

      if (!mounted) return;
      setState(() {
        _referenceFrames = referenceFrames;
        _currentFrameIndex = 0;
        _referenceLoadError = null;
      });
      if (_showLandmarkGuide && _isDynamicGesture && _isPlaying) {
        _startPlayback();
      }
    } on Exception catch (error) {
      debugPrint('Failed to load reference pose from $assetPath: $error');
      if (!mounted) return;
      setState(() {
        _referenceFrames = [];
        _referenceLoadError = 'Reference pose is unavailable.';
      });
    }
  }

  void _startPlayback() {
    _stopPlayback();
    if (!_isDynamicGesture || !_isPlaying || _referenceFrames.length < 2) {
      return;
    }
    final intervalMs = max(20, (40 / widget.playbackSpeed).round());
    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!mounted) return;
      setState(() {
        _currentFrameIndex = (_currentFrameIndex + 1) % _referenceFrames.length;
      });
    });
    setState(() {});
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  void _toggleGuide() {
    setState(() => _showLandmarkGuide = !_showLandmarkGuide);
    if (_showLandmarkGuide) {
      if (_isDynamicGesture && _isPlaying) _startPlayback();
    } else {
      _stopPlayback();
      _animationBridgeReady = false;
      _runViewerJavascript = null;
      _sendAnimationCommand();
    }
  }

  void _togglePlayback() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      if (_showLandmarkGuide) _startPlayback();
    } else {
      _stopPlayback();
    }
    _sendAnimationCommand();
  }

  void _sendAnimationCommand() {
    final assetPath = widget.referenceAssetPath;
    if (assetPath == null) return;
    final animationName = GestureAssetPaths.animationNameFor(
      assetPath,
      playbackSpeed: widget.playbackSpeed,
    );
    if (animationName == null) return;
    final command = jsonEncode({
      'animationName': animationName,
      'playing': _isPlaying,
    });

    if (kIsWeb) {
      avatar_animation_dispatcher.dispatchAvatarAnimation(command);
      return;
    }
    if (!_animationBridgeReady || _runViewerJavascript == null) return;

    unawaited(
      _runViewerJavascript!(
        'window.dispatchAvatarAnimationCommand(${jsonEncode(command)});',
      ).catchError((Object error) {
        debugPrint('Failed to control avatar animation: $error');
      }),
    );
  }

  @override
  void dispose() {
    _stopPlayback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: GestureDetector(
        onPanUpdate: _showLandmarkGuide && widget.isOrbitEnabled
            ? (details) =>
                  setState(() => _cameraRotationY += details.delta.dx * 0.01)
            : null,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF192A35), Color(0xFF101A24)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _GuideBackgroundPainter()),
              ),
              Center(
                child: !_showLandmarkGuide && widget.modelPath.isNotEmpty
                    ? _buildAvatar()
                    : _referenceLandmarks == null
                    ? _buildEmptyState()
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(_cameraRotationY),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            28,
                            _isDynamicGesture ? 82 : 62,
                            28,
                            _isDynamicGesture ? 64 : 56,
                          ),
                          child: CustomPaint(
                            painter: _ReferenceHandPainter(
                              landmarks: _referenceLandmarks!,
                              connections: _connections,
                              fingerColors: _fingerColors,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _badge(
                  icon: _showLandmarkGuide
                      ? Icons.account_tree_rounded
                      : Icons.view_in_ar_rounded,
                  text: _showLandmarkGuide
                      ? 'CAPTURED REFERENCE'
                      : _isDynamicGesture
                      ? 'SIGNING AVATAR'
                      : '3D AVATAR',
                  color: const Color(0xFF68E0D0),
                ),
              ),
              Positioned(
                top: 10,
                right: 9,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: _showLandmarkGuide
                          ? 'Show 3D avatar'
                          : 'Show landmark guide',
                      onPressed: _toggleGuide,
                      icon: Icon(
                        _showLandmarkGuide
                            ? Icons.view_in_ar_rounded
                            : Icons.account_tree_rounded,
                        color: const Color(0xFF68E0D0),
                        size: 19,
                      ),
                    ),
                    if (_isDynamicGesture) _speedButton(0.5),
                    if (_isDynamicGesture) _speedButton(0.75),
                    if (_isDynamicGesture) _speedButton(1.0),
                    if (_isDynamicGesture) const SizedBox(width: 3),
                    if (_isDynamicGesture)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: _isPlaying ? 'Pause gesture' : 'Play gesture',
                        onPressed: _togglePlayback,
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: const Color(0xFF68E0D0),
                          size: 19,
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: _isDynamicGesture ? 70 : 48,
                left: 14,
                right: 14,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (_showLandmarkGuide)
                Positioned(
                  bottom: 36,
                  left: 8,
                  right: 8,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 9,
                    runSpacing: 3,
                    children: List.generate(
                      _fingerNames.length,
                      (index) => _legendItem(
                        _fingerColors[index],
                        _fingerNames[index],
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      color: Color(0xFF68E0D0),
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _referenceLoadError ??
                            _animationError ??
                            (!_showLandmarkGuide
                                ? _isDynamicGesture
                                      ? _isPlaying
                                            ? 'Avatar signing • ${widget.playbackSpeed}x'
                                            : 'Avatar signing paused • Drag to rotate'
                                      : 'Drag to rotate • Pinch to zoom'
                                : _referenceLandmarks == null
                                ? 'Loading dataset pose...'
                                : _isDynamicGesture
                                ? 'Gesture playback • ${_currentFrameIndex + 1}/${_referenceFrames.length}'
                                : 'Numbered dots show the hand joints'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color:
                              _referenceLoadError == null &&
                                  _animationError == null
                              ? Colors.white70
                              : Colors.amberAccent,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    if (_isDynamicGesture)
                      Text(
                        '${widget.playbackSpeed}x',
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (_animationJavascript == null && _animationError == null) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Preparing sign animation',
        ),
      );
    }
    final animationName = widget.referenceAssetPath == null
        ? null
        : GestureAssetPaths.animationNameFor(
            widget.referenceAssetPath!,
            playbackSpeed: widget.playbackSpeed,
          );
    return ModelViewer(
            src: kIsWeb ? 'assets/${widget.modelPath}' : widget.modelPath,
      id: 'gesture-avatar-model',
      alt: 'Interactive 3D sign-language avatar',
      backgroundColor: Colors.transparent,
      cameraControls: true,
      autoRotate: false,
      disableZoom: false,
      interactionPrompt: InteractionPrompt.none,
      cameraOrbit: '0deg 75deg 115%',
      minCameraOrbit: 'auto auto 60%',
      maxCameraOrbit: 'auto auto 180%',
      animationName: animationName,
      autoPlay: animationName != null && _isPlaying,
      relatedJs: _animationJavascript,
      javascriptChannels: {
        JavascriptChannel(
          'AvatarAnimationBridge',
          onMessageReceived: (message) {
            if (message.message == 'ready') {
              _animationBridgeReady = true;
              _sendAnimationCommand();
            } else if (message.message.startsWith('error:')) {
              debugPrint(message.message);
              if (mounted) {
                setState(() {
                  _animationError = 'This sign animation could not be loaded.';
                });
              }
            }
          },
        ),
      },
      onWebViewCreated: (controller) {
        _runViewerJavascript = controller.runJavaScript;
      },
    );
  }

  Widget _speedButton(double speed) {
    final selected = widget.playbackSpeed == speed;
    return Padding(
      padding: const EdgeInsets.only(left: 3),
      child: Material(
        color: selected ? const Color(0xFF4385FF) : const Color(0xCC101820),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: () => widget.onPlaybackSpeedChanged?.call(speed),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            child: Text(
              '${speed}x',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 8),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    if (_referenceLoadError != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          _referenceLoadError!,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.amberAccent, fontSize: 12),
        ),
      );
    }
    return const CircularProgressIndicator(
      color: Color(0xFF68E0D0),
      strokeWidth: 2,
    );
  }

  Widget _badge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC101820),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: .36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceHandPainter extends CustomPainter {
  final List<HandLandmark> landmarks;
  final List<List<int>> connections;
  final List<Color> fingerColors;

  const _ReferenceHandPainter({
    required this.landmarks,
    required this.connections,
    required this.fingerColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty || size.isEmpty) return;
    final minX = landmarks
        .map((point) => point.x)
        .reduce((a, b) => a < b ? a : b);
    final maxX = landmarks
        .map((point) => point.x)
        .reduce((a, b) => a > b ? a : b);
    final minY = landmarks
        .map((point) => point.y)
        .reduce((a, b) => a < b ? a : b);
    final maxY = landmarks
        .map((point) => point.y)
        .reduce((a, b) => a > b ? a : b);
    final handWidth = (maxX - minX).clamp(.0001, double.infinity);
    final handHeight = (maxY - minY).clamp(.0001, double.infinity);
    final scale =
        (size.width / handWidth < size.height / handHeight
            ? size.width / handWidth
            : size.height / handHeight) *
        .93;
    final offset = Offset(
      (size.width - handWidth * scale) / 2,
      (size.height - handHeight * scale) / 2,
    );
    final positions = <int, Offset>{
      for (final point in landmarks)
        point.id: Offset(
          offset.dx + (point.x - minX) * scale,
          offset.dy + (point.y - minY) * scale,
        ),
    };

    final palmPoints = [
      0,
      5,
      9,
      13,
      17,
    ].map((id) => positions[id]).whereType<Offset>().toList();
    if (palmPoints.length == 5) {
      final palm = Path()..moveTo(palmPoints.first.dx, palmPoints.first.dy);
      for (final point in palmPoints.skip(1)) {
        palm.lineTo(point.dx, point.dy);
      }
      palm.close();
      canvas.drawPath(
        palm,
        Paint()
          ..color = const Color(0xFF45CFC2).withValues(alpha: .13)
          ..style = PaintingStyle.fill,
      );
    }

    final shadowPaint = Paint()
      ..color = const Color(0xFF071218).withValues(alpha: .75)
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    for (final connection in connections) {
      final start = positions[connection[0]];
      final end = positions[connection[1]];
      if (start == null || end == null) continue;
      final fingerIndex = _fingerIndex(connection);
      final color = fingerIndex == null
          ? const Color(0xFF78E5D7)
          : fingerColors[fingerIndex];
      canvas.drawLine(start, end, shadowPaint);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = color
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final point in landmarks) {
      final position = positions[point.id]!;
      final fingerIndex = _fingerIndexForLandmark(point.id);
      final color = fingerIndex == null
          ? const Color(0xFF78E5D7)
          : fingerColors[fingerIndex];
      canvas.drawCircle(position, 7, Paint()..color = const Color(0xFF071218));
      canvas.drawCircle(position, 5.5, Paint()..color = color);

      final label = TextPainter(
        text: TextSpan(
          text: '${point.id}',
          style: const TextStyle(
            color: Color(0xFF101820),
            fontSize: 7,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        position.translate(-label.width / 2, -label.height / 2),
      );
    }
  }

  int? _fingerIndex(List<int> connection) {
    final landmarkId = connection.firstWhere((id) => id != 0);
    return _fingerIndexForLandmark(landmarkId);
  }

  int? _fingerIndexForLandmark(int id) {
    if (id >= 1 && id <= 4) return 0;
    if (id >= 5 && id <= 8) return 1;
    if (id >= 9 && id <= 12) return 2;
    if (id >= 13 && id <= 16) return 3;
    if (id >= 17 && id <= 20) return 4;
    return null;
  }

  @override
  bool shouldRepaint(covariant _ReferenceHandPainter oldDelegate) =>
      oldDelegate.landmarks != landmarks;
}

class _GuideBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .035)
      ..strokeWidth = 1;
    const gap = 28.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GuideBackgroundPainter oldDelegate) => false;
}
