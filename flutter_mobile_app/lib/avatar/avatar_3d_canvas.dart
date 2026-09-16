import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'avatar_controller.dart';
import '../models/alert_level.dart';
import '../models/detection_event.dart';

/// 3D Vector representation
class Vector3D {
  double x, y, z;
  Vector3D(this.x, this.y, this.z);

  Vector3D operator +(Vector3D v) => Vector3D(x + v.x, y + v.y, z + v.z);
  Vector3D operator -(Vector3D v) => Vector3D(x - v.x, y - v.y, z - v.z);
  Vector3D operator *(double s) => Vector3D(x * s, y * s, z * s);

  Vector3D cross(Vector3D v) => Vector3D(
        y * v.z - z * v.y,
        z * v.x - x * v.z,
        x * v.y - y * v.x,
      );

  double dot(Vector3D v) => x * v.x + y * v.y + z * v.z;

  double get length => math.sqrt(x * x + y * y + z * z);

  Vector3D normalize() {
    final l = length;
    if (l == 0) return Vector3D(0, 0, 1);
    return Vector3D(x / l, y / l, z / l);
  }
}

/// 3D Polygon with Realistic Human Skin / Fabric Shading
class Polygon3D {
  final List<Vector3D> vertices;
  final Color baseColor;
  final double specularPower;
  final bool isEmissive;

  Polygon3D({
    required this.vertices,
    required this.baseColor,
    this.specularPower = 16.0,
    this.isEmissive = false,
  });

  Vector3D get normal {
    if (vertices.length < 3) return Vector3D(0, 0, 1);
    final v1 = vertices[1] - vertices[0];
    final v2 = vertices[2] - vertices[0];
    return v1.cross(v2).normalize();
  }

  double get averageZ {
    if (vertices.isEmpty) return 0;
    double sum = 0;
    for (var v in vertices) {
      sum += v.z;
    }
    return sum / vertices.length;
  }
}

/// Real Moving Realistic 3D Human AI Avatar
class Avatar3DCanvas extends StatefulWidget {
  final AvatarController controller;
  final double height;

  const Avatar3DCanvas({
    Key? key,
    required this.controller,
    this.height = 360,
  }) : super(key: key);

  @override
  State<Avatar3DCanvas> createState() => _Avatar3DCanvasState();
}

class _Avatar3DCanvasState extends State<Avatar3DCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  double _yaw = 0.0;
  double _pitch = 0.04;
  double _zoom = 1.0;
  bool _autoOrbit = true;

  double _lastFocalPointX = 0;
  double _lastFocalPointY = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _resetCamera() {
    setState(() {
      _yaw = 0.0;
      _pitch = 0.04;
      _zoom = 1.0;
      _autoOrbit = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_animController, widget.controller]),
      builder: (context, child) {
        final time = _animController.value * 2 * math.pi * 5;
        final state = widget.controller.state;
        final DetectionEvent? event = widget.controller.currentEvent;

        double currentYaw = _yaw;
        if (_autoOrbit) {
          currentYaw += math.sin(time * 0.35) * 0.15;
        }

        return Stack(
          children: [
            // 3D Viewport with 360° Touch Orbit Control
            GestureDetector(
              onScaleStart: (details) {
                _lastFocalPointX = details.focalPoint.dx;
                _lastFocalPointY = details.focalPoint.dy;
                setState(() {
                  _autoOrbit = false;
                });
              },
              onScaleUpdate: (details) {
                setState(() {
                  final dx = details.focalPoint.dx - _lastFocalPointX;
                  final dy = details.focalPoint.dy - _lastFocalPointY;
                  _lastFocalPointX = details.focalPoint.dx;
                  _lastFocalPointY = details.focalPoint.dy;

                  _yaw += dx * 0.012;
                  _pitch = (_pitch + dy * 0.012).clamp(-0.45, 0.45);
                  _zoom = (_zoom * details.scale).clamp(0.75, 1.4);
                });
              },
              child: Container(
                height: widget.height,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const RadialGradient(
                    center: Alignment(0, -0.25),
                    radius: 1.25,
                    colors: [
                      Color(0xFF1E283C),
                      Color(0xFF0F1524),
                      Color(0xFF070A12),
                    ],
                  ),
                ),
                child: CustomPaint(
                  painter: _Avatar3DScenePainter(
                    yaw: currentYaw,
                    pitch: _pitch,
                    zoom: _zoom,
                    time: time,
                    state: state,
                    event: event,
                  ),
                ),
              ),
            ),

            // Top Status Badge
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: _buildFloatingHudHeader(state, event),
            ),

            // Bottom Controls
            Positioned(
              bottom: 10,
              right: 12,
              child: Row(
                children: [
                  _buildControlPill(
                    icon: _autoOrbit ? Icons.sync_rounded : Icons.pause_circle_filled_rounded,
                    label: _autoOrbit ? "3D Auto" : "Manual",
                    onTap: () {
                      setState(() {
                        _autoOrbit = !_autoOrbit;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildControlPill(
                    icon: Icons.refresh_rounded,
                    label: "Center",
                    onTap: _resetCamera,
                  ),
                ],
              ),
            ),

            // Bottom Left Human Avatar State Tag
            Positioned(
              bottom: 12,
              left: 14,
              child: _buildPoseStatusTag(state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingHudHeader(AvatarState state, DetectionEvent? event) {
    Color accent = const Color(0xFF00E5FF);
    String status = "REAL HUMAN AI AVATAR: READY";
    IconData icon = Icons.person_rounded;

    if (state == AvatarState.listening) {
      accent = const Color(0xFF00E5FF);
      status = "👂 ACTIVE VOICE & SOUND MONITORING";
      icon = Icons.hearing_rounded;
    } else if (state == AvatarState.highAlert) {
      accent = AlertLevel.high.color;
      status = "🚨 HIGH EMERGENCY ALERT DETECTED";
      icon = Icons.warning_rounded;
    } else if (state == AvatarState.mediumAlert) {
      accent = AlertLevel.medium.color;
      status = "⚠️ CAUTION WARNING DETECTED";
      icon = Icons.error_outline_rounded;
    } else if (state == AvatarState.lowAlert) {
      accent = AlertLevel.low.color;
      status = "ℹ️ LOW NOTICE";
      icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101622).withOpacity(0.90),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.25),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                status,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          if (event != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accent),
              ),
              child: Text(
                '${(event.confidence * 100).toStringAsFixed(0)}% Conf',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF141A26).withOpacity(0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoseStatusTag(AvatarState state) {
    String poseText = "Human Avatar: Breathing & Ready";
    Color col = const Color(0xFF00E5FF);

    if (state == AvatarState.listening) {
      poseText = "Human Avatar: Active Receptive Listening";
      col = const Color(0xFF00E5FF);
    } else if (state == AvatarState.highAlert) {
      poseText = "Human Avatar: 🚨 Raised-Palm Emergency Gesture";
      col = AlertLevel.high.color;
    } else if (state == AvatarState.mediumAlert) {
      poseText = "Human Avatar: ⚠️ Caution Warning Gesture";
      col = AlertLevel.medium.color;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: col.withOpacity(0.4)),
      ),
      child: Text(
        poseText,
        style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// 3D Scene Painter with Real-Time Matrix Transform & Realistic Human Mesh
class _Avatar3DScenePainter extends CustomPainter {
  final double yaw;
  final double pitch;
  final double zoom;
  final double time;
  final AvatarState state;
  final DetectionEvent? event;

  _Avatar3DScenePainter({
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.time,
    required this.state,
    required this.event,
  });

  @override
  bool shouldRepaint(covariant _Avatar3DScenePainter oldDelegate) => true;


  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);

    // 1. Dual Realistic Studio Lighting
    final keyLight = Vector3D(0.45, -0.65, 0.8).normalize();

    // 2. Generate Anatomically Realistic 3D Human Model Geometry
    final polygons = _generateRealisticHumanGeometry(time, state, event);

    // 3. Transform & Perspective Project Geometry
    final List<TransformedPolygon> transformedPolygons = [];
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    const fov = 430.0;

    for (var poly in polygons) {
      final List<Offset> screenPoints = [];
      final List<Vector3D> viewVertices = [];
      bool allInFront = true;

      for (var v in poly.vertices) {
        var x1 = v.x * cosYaw - v.z * sinYaw;
        var y1 = v.y;
        var z1 = v.x * sinYaw + v.z * cosYaw;

        var x2 = x1;
        var y2 = y1 * cosPitch - z1 * sinPitch;
        var z2 = y1 * sinPitch + z1 * cosPitch;

        z2 += 340.0 / zoom;

        if (z2 <= 20) {
          allInFront = false;
          break;
        }

        final scale = fov / z2;
        final sx = center.dx + x2 * scale;
        final sy = center.dy + y2 * scale;

        screenPoints.add(Offset(sx, sy));
        viewVertices.add(Vector3D(x2, y2, z2));
      }

      if (!allInFront || screenPoints.length < 3) continue;

      final v1 = viewVertices[1] - viewVertices[0];
      final v2 = viewVertices[2] - viewVertices[0];
      final normal = v1.cross(v2).normalize();

      if (normal.z <= -0.15 && !poly.isEmissive) continue;

      double avgZ = 0;
      for (var v in viewVertices) {
        avgZ += v.z;
      }
      avgZ /= viewVertices.length;

      // Realistic Human Skin & Fabric Subsurface Lighting
      Color shadedColor = poly.baseColor;
      if (!poly.isEmissive) {
        final dotLight = normal.dot(keyLight).clamp(0.0, 1.0);
        final ambient = 0.44; // Soft realistic skin ambient
        final diffuse = 0.56 * dotLight;
        final brightness = (ambient + diffuse).clamp(0.0, 1.0);

        double spec = 0.0;
        if (dotLight > 0) {
          final viewDir = Vector3D(0, 0, 1);
          final halfVec = (keyLight + viewDir).normalize();
          final dotHalf = normal.dot(halfVec).clamp(0.0, 1.0);
          spec = math.pow(dotHalf, poly.specularPower) * 0.18; // Soft human skin sheen
        }

        shadedColor = _applyLighting(poly.baseColor, brightness, spec);
      }

      transformedPolygons.add(
        TransformedPolygon(
          points: screenPoints,
          depthZ: avgZ,
          color: shadedColor,
          isEmissive: poly.isEmissive,
        ),
      );
    }

    // 4. Depth Sorting (Painter's Algorithm)
    transformedPolygons.sort((a, b) => b.depthZ.compareTo(a.depthZ));

    // 5. Draw 3D Floating Base Halo & Acoustic Waves
    _draw3DAcousticWaves(canvas, center, time, state);

    // 6. Rasterize Realistic 3D Human Geometry
    final paint = Paint()..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4;

    for (var tp in transformedPolygons) {
      final path = Path()..moveTo(tp.points[0].dx, tp.points[0].dy);
      for (int i = 1; i < tp.points.length; i++) {
        path.lineTo(tp.points[i].dx, tp.points[i].dy);
      }
      path.close();

      paint.color = tp.color;
      canvas.drawPath(path, paint);

      if (tp.isEmissive) {
        edgePaint.color = Colors.white.withOpacity(0.4);
        canvas.drawPath(path, edgePaint);
      } else {
        edgePaint.color = Colors.black.withOpacity(0.06);
        canvas.drawPath(path, edgePaint);
      }
    }
  }

  Color _applyLighting(Color base, double brightness, double specular) {
    int r = ((base.red * brightness) + (specular * 255)).clamp(0, 255).toInt();
    int g = ((base.green * brightness) + (specular * 255)).clamp(0, 255).toInt();
    int b = ((base.blue * brightness) + (specular * 255)).clamp(0, 255).toInt();
    return Color.fromARGB(base.alpha, r, g, b);
  }

  /// Generates the REALISTIC 3D Human AI Avatar Model
  List<Polygon3D> _generateRealisticHumanGeometry(
    double time,
    AvatarState state,
    DetectionEvent? event,
  ) {
    final List<Polygon3D> list = [];

    // Natural Human Harmonic Kinematics
    final breath = math.sin(time * 1.6) * 2.2;
    final eyeBlink = (math.sin(time * 0.65) > 0.93) ? 0.10 : 1.0; // Human blinking
    final headTilt = (state == AvatarState.listening)
        ? math.sin(time * 2.0) * 5.5
        : math.sin(time * 0.7) * 2.2;

    double alertArmLift = 0.0;
    double alertHandSpread = 0.0;
    if (state == AvatarState.highAlert) {
      alertArmLift = 40.0 + math.sin(time * 5.0) * 3.0; // Urgently raised human palm
      alertHandSpread = 14.0;
    } else if (state == AvatarState.mediumAlert) {
      alertArmLift = 22.0 + math.sin(time * 2.5) * 2.0;
      alertHandSpread = 8.0;
    } else if (state == AvatarState.listening) {
      alertArmLift = 12.0;
    }

    // Realistic Human Skin, Facial & Clothing Palette
    const skinTone = Color(0xFFE8BC9C); // Natural human complexion
    const skinShade = Color(0xFFD49E7C); // Natural shadow tone
    const skinHighlight = Color(0xFFF3CFB4); // Cheekbone highlight
    const lipColor = Color(0xFFD46372); // Natural rose lips
    const hairDarkBrown = Color(0xFF281C16); // Rich brunette human hair
    const hairSheen = Color(0xFF483428); // Hair light reflection
    const clothingJacket = Color(0xFF1B283A); // Professional navy tailored blazer
    const clothingLapel = Color(0xFF142030); // Blazer lapel contour
    const clothingBlouse = Color(0xFFF0F4FA); // Clean blouse

    // ==========================================
    // 1. HUMAN TORSO & CLOTHING (Breathing Dynamics)
    // ==========================================
    final torsoY = 44.0 + breath * 0.4;
    final chestDepth = 22.0 + breath * 0.5;

    // Tailored Blazer Torso
    _create3DBox(
      list,
      center: Vector3D(0, torsoY + 22, 0),
      size: Vector3D(52, 44, chestDepth),
      color: clothingJacket,
      topColor: clothingLapel,
    );

    // Inner Blouse
    _create3DBox(
      list,
      center: Vector3D(0, torsoY + 12, chestDepth / 2 + 1.2),
      size: Vector3D(16, 20, 2),
      color: clothingBlouse,
    );

    // ==========================================
    // 2. HUMAN SHOULDERS & ARMS
    // ==========================================
    // Left Arm (Natural Resting Human Pose)
    _create3DSphere(list, center: Vector3D(-33, torsoY, 0), radius: 8.5, color: clothingJacket);
    _create3DCylinder(
      list,
      p1: Vector3D(-33, torsoY, 0),
      p2: Vector3D(-39, torsoY + 36, 6),
      radius: 5.5,
      color: clothingJacket,
    );
    // Left Hand & Articulated Fingers
    _create3DBox(
      list,
      center: Vector3D(-39, torsoY + 44, 8),
      size: Vector3D(6.5, 9, 5),
      color: skinTone,
    );

    // Right Arm (DYNAMICS: Raised Palm Warning Gesture)
    final rShoulder = Vector3D(33, torsoY, 0);
    final rHandY = (torsoY + 36) - alertArmLift;
    final rHandZ = (alertArmLift > 0) ? 28.0 : 6.0;
    final rHandX = 39.0 + alertHandSpread;

    _create3DSphere(list, center: rShoulder, radius: 8.5, color: clothingJacket);
    _create3DCylinder(
      list,
      p1: rShoulder,
      p2: Vector3D(rHandX, rHandY, rHandZ),
      radius: 5.5,
      color: clothingJacket,
    );
    // Right Hand (Palm Raised Forward in Warning)
    _create3DBox(
      list,
      center: Vector3D(rHandX, rHandY - 6, rHandZ + 4),
      size: Vector3D(8, 12, 4),
      color: skinTone,
    );

    // ==========================================
    // 3. HUMAN NECK & COLLARBONE
    // ==========================================
    final neckY = torsoY - 14;
    _create3DCylinder(
      list,
      p1: Vector3D(0, torsoY - 2, 0),
      p2: Vector3D(0, neckY, 0),
      radius: 7.5,
      color: skinShade,
    );

    // ==========================================
    // 4. REALISTIC HUMAN HEAD & FACIAL ANATOMY
    // ==========================================
    final headCenter = Vector3D(headTilt * 0.35, neckY - 28, 0);

    // Smooth Human Cranium & Facial Base
    _create3DBox(
      list,
      center: headCenter,
      size: Vector3D(30, 36, 28),
      color: skinTone,
    );
    // Cheekbones & Contoured Face
    _create3DBox(
      list,
      center: Vector3D(headCenter.x, headCenter.y + 4, headCenter.z + 10),
      size: Vector3D(26, 16, 12),
      color: skinHighlight,
    );
    // Natural Human Chin & Jaw
    _create3DBox(
      list,
      center: Vector3D(headCenter.x, headCenter.y + 16, headCenter.z + 5),
      size: Vector3D(16, 9, 14),
      color: skinShade,
    );

    // ==========================================
    // 5. REALISTIC HUMAN EYES, EYEBROWS, NOSE & LIPS
    // ==========================================
    final eyeY = headCenter.y - 3;
    final eyeZ = headCenter.z + 15.2;
    final eyeHeight = 4.5 * eyeBlink;

    // Curved Natural Eyebrows
    _create3DBox(
      list,
      center: Vector3D(headCenter.x - 7.5, eyeY - 5, eyeZ + 0.5),
      size: Vector3D(8, 1.8, 1.5),
      color: hairDarkBrown,
    );
    _create3DBox(
      list,
      center: Vector3D(headCenter.x + 7.5, eyeY - 5, eyeZ + 0.5),
      size: Vector3D(8, 1.8, 1.5),
      color: hairDarkBrown,
    );

    // Left Eye (White Sclera + Hazel Iris + Pupil)
    _create3DBox(
      list,
      center: Vector3D(headCenter.x - 7.5, eyeY, eyeZ),
      size: Vector3D(6, eyeHeight, 1.5),
      color: Colors.white,
    );
    _create3DBox(
      list,
      center: Vector3D(headCenter.x - 7.5, eyeY, eyeZ + 0.7),
      size: Vector3D(3, eyeHeight * 0.8, 1.2),
      color: const Color(0xFF4A3220), // Hazel Iris
    );
    _create3DBox(
      list,
      center: Vector3D(headCenter.x - 7.5, eyeY, eyeZ + 1.2),
      size: Vector3D(1.4, eyeHeight * 0.5, 0.8),
      color: Colors.black, // Pupil
    );

    // Right Eye (White Sclera + Hazel Iris + Pupil)
    _create3DBox(
      list,
      center: Vector3D(headCenter.x + 7.5, eyeY, eyeZ),
      size: Vector3D(6, eyeHeight, 1.5),
      color: Colors.white,
    );
    _create3DBox(
      list,
      center: Vector3D(headCenter.x + 7.5, eyeY, eyeZ + 0.7),
      size: Vector3D(3, eyeHeight * 0.8, 1.2),
      color: const Color(0xFF4A3220), // Hazel Iris
    );
    _create3DBox(
      list,
      center: Vector3D(headCenter.x + 7.5, eyeY, eyeZ + 1.2),
      size: Vector3D(1.4, eyeHeight * 0.5, 0.8),
      color: Colors.black, // Pupil
    );

    // Realistic Human Nose Bridge & Tip
    _create3DBox(
      list,
      center: Vector3D(headCenter.x, headCenter.y + 4, eyeZ + 2.5),
      size: Vector3D(3.5, 7.5, 4.5),
      color: skinShade,
    );

    // Full Contoured Rose Human Lips
    _create3DBox(
      list,
      center: Vector3D(headCenter.x, headCenter.y + 12.5, eyeZ + 2.0),
      size: Vector3D(8.5, 3.2, 2.0),
      color: lipColor,
    );

    // ==========================================
    // 6. NATURAL FLOWING BRUNETTE HUMAN HAIR
    // ==========================================
    // Top Crown & Parting
    _create3DBox(
      list,
      center: Vector3D(headCenter.x, headCenter.y - 18, headCenter.z - 2),
      size: Vector3D(34, 11, 32),
      color: hairDarkBrown,
      topColor: hairSheen,
    );
    // Soft Bangs Framing Forehead
    _create3DBox(
      list,
      center: Vector3D(headCenter.x, headCenter.y - 10, headCenter.z + 13),
      size: Vector3D(28, 6, 4),
      color: hairDarkBrown,
    );
    // Back Hair Flow
    _create3DBox(
      list,
      center: Vector3D(headCenter.x, headCenter.y + 6, headCenter.z - 15),
      size: Vector3D(36, 46, 12),
      color: hairDarkBrown,
    );
    // Left & Right Shoulder Hair Cascades
    _create3DBox(
      list,
      center: Vector3D(headCenter.x - 17, headCenter.y + 6, headCenter.z),
      size: Vector3D(5.5, 42, 28),
      color: hairDarkBrown,
    );
    _create3DBox(
      list,
      center: Vector3D(headCenter.x + 17, headCenter.y + 6, headCenter.z),
      size: Vector3D(5.5, 42, 28),
      color: hairDarkBrown,
    );

    return list;
  }

  void _draw3DAcousticWaves(
    Canvas canvas,
    Offset center,
    double time,
    AvatarState state,
  ) {
    final floorY = center.dy + 105;
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Color ringColor = (state == AvatarState.highAlert)
        ? AlertLevel.high.color
        : (state == AvatarState.mediumAlert)
            ? AlertLevel.medium.color
            : const Color(0xFF00E5FF);

    for (int i = 1; i <= 3; i++) {
      final radX = 85.0 * i / 2.0 + math.sin(time * 2.0 + i) * 3.0;
      final radY = radX * 0.32;

      wavePaint.color = ringColor.withOpacity((0.55 / i).clamp(0.1, 0.55));
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx, floorY), width: radX * 2, height: radY * 2),
        wavePaint,
      );
    }
  }

  // Primitive Helper Generators
  void _create3DBox(
    List<Polygon3D> list, {
    required Vector3D center,
    required Vector3D size,
    required Color color,
    Color? topColor,
  }) {
    final hx = size.x / 2;
    final hy = size.y / 2;
    final hz = size.z / 2;

    final p0 = center + Vector3D(-hx, -hy, -hz);
    final p1 = center + Vector3D(hx, -hy, -hz);
    final p2 = center + Vector3D(hx, hy, -hz);
    final p3 = center + Vector3D(-hx, hy, -hz);
    final p4 = center + Vector3D(-hx, -hy, hz);
    final p5 = center + Vector3D(hx, -hy, hz);
    final p6 = center + Vector3D(hx, hy, hz);
    final p7 = center + Vector3D(-hx, hy, hz);

    // Front (+Z)
    list.add(Polygon3D(vertices: [p4, p5, p6, p7], baseColor: color));
    // Back (-Z)
    list.add(Polygon3D(vertices: [p1, p0, p3, p2], baseColor: color));
    // Top (-Y)
    list.add(Polygon3D(vertices: [p0, p1, p5, p4], baseColor: topColor ?? color));
    // Bottom (+Y)
    list.add(Polygon3D(vertices: [p3, p7, p6, p2], baseColor: color));
    // Right (+X)
    list.add(Polygon3D(vertices: [p1, p2, p6, p5], baseColor: color));
    // Left (-X)
    list.add(Polygon3D(vertices: [p0, p4, p7, p3], baseColor: color));
  }

  void _create3DSphere(
    List<Polygon3D> list, {
    required Vector3D center,
    required double radius,
    required Color color,
  }) {
    _create3DBox(
      list,
      center: center,
      size: Vector3D(radius * 1.8, radius * 1.8, radius * 1.8),
      color: color,
    );
  }

  void _create3DCylinder(
    List<Polygon3D> list, {
    required Vector3D p1,
    required Vector3D p2,
    required double radius,
    required Color color,
  }) {
    final mid = (p1 + p2) * 0.5;
    final len = (p2 - p1).length;
    _create3DBox(
      list,
      center: mid,
      size: Vector3D(radius * 2, len, radius * 2),
      color: color,
    );
  }
}

class TransformedPolygon {
  final List<Offset> points;
  final double depthZ;
  final Color color;
  final bool isEmissive;

  TransformedPolygon({
    required this.points,
    required this.depthZ,
    required this.color,
    this.isEmissive = false,
  });
}
