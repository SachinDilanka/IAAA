import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_scaffold.dart';
import '../../features/app/app_controller.dart';
import '../../l10n/l10n.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final startRoute = controller.child?.currentLevel == 'words'
        ? '/words'
        : '/letters';

    return AppScaffold(
      currentIndex: 0,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ParkHero(onStart: () => context.go(startRoute)),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = [
                  _PracticeCard(
                    title: context.l10n.letterPractice,
                    subtitle: context.l10n.letterPracticeDescription,
                    color: const Color(0xFF8B5CF6),
                    background: const [Color(0xFFF4E8FF), Color(0xFFFFE8F2)],
                    artwork: const _LetterArtwork(),
                    onTap: () => context.go('/letters'),
                  ),
                  _PracticeCard(
                    title: context.l10n.wordPractice,
                    subtitle: context.l10n.wordPracticeDescription,
                    color: const Color(0xFFF06449),
                    background: const [Color(0xFFFFF2D6), Color(0xFFE4FAE7)],
                    artwork: const _WordArtwork(),
                    onTap: () => context.go('/words'),
                  ),
                ];

                if (constraints.maxWidth < 720) {
                  return Column(
                    children: [
                      cards.first,
                      const SizedBox(height: 16),
                      cards.last,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards.first),
                    const SizedBox(width: 18),
                    Expanded(child: cards.last),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ParkHero extends StatelessWidget {
  const _ParkHero({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;
        return Container(
          height: compact ? 470 : 420,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Color(0x260EA5E9),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ExcludeSemantics(
                child: CustomPaint(painter: _ParkScenePainter()),
              ),
              Positioned(
                bottom: compact ? 22 : 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Semantics(
                    button: true,
                    label: context.l10n.start,
                    child: _GlossyStartButton(
                      label: context.l10n.start,
                      onPressed: onStart,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlossyStartButton extends StatefulWidget {
  const _GlossyStartButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_GlossyStartButton> createState() => _GlossyStartButtonState();
}

class _GlossyStartButtonState extends State<_GlossyStartButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? .96 : 1,
      duration: const Duration(milliseconds: 110),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed();
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: 190),
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5FA2),
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33D91F72),
                blurRadius: 0,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .2,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeCard extends StatefulWidget {
  const _PracticeCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.artwork,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final List<Color> background;
  final Widget artwork;
  final VoidCallback onTap;

  @override
  State<_PracticeCard> createState() => _PracticeCardState();
}

class _PracticeCardState extends State<_PracticeCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.015 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(28),
            child: Ink(
              height: 250,
              padding: const EdgeInsets.fromLTRB(24, 20, 22, 20),
              decoration: BoxDecoration(
                color: widget.background.first,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: .16),
                    blurRadius: _hovering ? 24 : 16,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: const Color(0xFF263B55),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.subtitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF52677D)),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: widget.color,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(flex: 4, child: widget.artwork),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterArtwork extends StatelessWidget {
  const _LetterArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned(
          top: 8,
          right: 8,
          child: Icon(
            Icons.music_note_rounded,
            color: Color(0xFFF43F8C),
            size: 34,
          ),
        ),
        const Positioned(
          bottom: 14,
          left: 4,
          child: Icon(
            Icons.music_note_rounded,
            color: Color(0xFF06B6D4),
            size: 27,
          ),
        ),
        Transform.rotate(
          angle: -.12,
          child: const _BouncyLetter(
            letter: 'අ',
            color: Color(0xFFF97316),
            size: 72,
          ),
        ),
        Positioned(
          right: 2,
          bottom: 30,
          child: Transform.rotate(
            angle: .15,
            child: const _BouncyLetter(
              letter: 'ක',
              color: Color(0xFF8B5CF6),
              size: 58,
            ),
          ),
        ),
      ],
    );
  }
}

class _BouncyLetter extends StatelessWidget {
  const _BouncyLetter({
    required this.letter,
    required this.color,
    required this.size,
  });

  final String letter;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 18,
      height: size + 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .66),
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size,
          height: 1,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _WordArtwork extends StatelessWidget {
  const _WordArtwork();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _WordIconsPainter(), size: Size.infinite);
  }
}

class _ParkScenePainter extends CustomPainter {
  const _ParkScenePainter();

  static const _sky = Color(0xFFDDF4FF);
  static const _farHill = Color(0xFFB8E6A3);
  static const _nearHill = Color(0xFF82D17B);
  static const _leaf = Color(0xFF62BF73);
  static const _leafLight = Color(0xFF7DD087);
  static const _trunk = Color(0xFFC88B62);
  static const _skin = Color(0xFFE3A078);
  static const _face = Color(0xFF594A50);

  @override
  void paint(Canvas canvas, Size size) {
    const designSize = Size(1000, 430);
    canvas.save();
    canvas.scale(
      size.width / designSize.width,
      size.height / designSize.height,
    );

    canvas.drawRect(Offset.zero & designSize, Paint()..color = _sky);
    _circle(canvas, const Offset(865, 76), 45, const Color(0xFFFFD866));
    _cloud(canvas, const Offset(145, 76), 1);
    _cloud(canvas, const Offset(720, 120), .72);

    final farHill = Path()
      ..moveTo(0, 278)
      ..quadraticBezierTo(190, 190, 390, 276)
      ..quadraticBezierTo(660, 165, 1000, 270)
      ..lineTo(1000, 430)
      ..lineTo(0, 430)
      ..close();
    canvas.drawPath(farHill, Paint()..color = _farHill);

    final nearHill = Path()
      ..moveTo(0, 326)
      ..quadraticBezierTo(250, 262, 510, 325)
      ..quadraticBezierTo(760, 255, 1000, 316)
      ..lineTo(1000, 430)
      ..lineTo(0, 430)
      ..close();
    canvas.drawPath(nearHill, Paint()..color = _nearHill);

    _tree(canvas, const Offset(105, 294), 1.05);
    _tree(canvas, const Offset(900, 300), .95);
    _tree(canvas, const Offset(210, 314), .62);

    _child(
      canvas,
      const Offset(350, 238),
      shirt: const Color(0xFF69BDEB),
      hair: const Color(0xFF725347),
      girl: false,
    );
    _lion(canvas, const Offset(500, 238));
    _child(
      canvas,
      const Offset(650, 238),
      shirt: const Color(0xFFF38AB6),
      hair: const Color(0xFF5D463F),
      girl: true,
    );

    canvas.restore();
  }

  void _cloud(Canvas canvas, Offset center, double scale) {
    const color = Colors.white;
    _circle(canvas, center.translate(-30 * scale, 5), 24 * scale, color);
    _circle(canvas, center.translate(0, -8 * scale), 33 * scale, color);
    _circle(canvas, center.translate(35 * scale, 4), 25 * scale, color);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(2, 10 * scale),
          width: 98 * scale,
          height: 30 * scale,
        ),
        Radius.circular(18 * scale),
      ),
      Paint()..color = color,
    );
  }

  void _tree(Canvas canvas, Offset base, double scale) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: base.translate(0, -48 * scale),
          width: 26 * scale,
          height: 96 * scale,
        ),
        Radius.circular(10 * scale),
      ),
      Paint()..color = _trunk,
    );
    _circle(
      canvas,
      base.translate(-24 * scale, -101 * scale),
      40 * scale,
      _leaf,
    );
    _circle(
      canvas,
      base.translate(22 * scale, -108 * scale),
      48 * scale,
      _leafLight,
    );
    _circle(canvas, base.translate(0, -73 * scale), 45 * scale, _leaf);
  }

  void _child(
    Canvas canvas,
    Offset center, {
    required Color shirt,
    required Color hair,
    required bool girl,
  }) {
    final limbPaint = Paint()
      ..color = _skin
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final legPaint = Paint()
      ..color = const Color(0xFF6C7894)
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center.translate(-19, 66),
      center.translate(-24, 105),
      legPaint,
    );
    canvas.drawLine(
      center.translate(19, 66),
      center.translate(24, 105),
      legPaint,
    );
    _circle(canvas, center.translate(-26, 108), 10, const Color(0xFFFFF8E8));
    _circle(canvas, center.translate(26, 108), 10, const Color(0xFFFFF8E8));

    final body = Path()
      ..moveTo(center.dx - 31, center.dy + 10)
      ..quadraticBezierTo(
        center.dx,
        center.dy - 2,
        center.dx + 31,
        center.dy + 10,
      )
      ..lineTo(center.dx + 25, center.dy + 70)
      ..lineTo(center.dx - 25, center.dy + 70)
      ..close();
    canvas.drawPath(body, Paint()..color = shirt);

    canvas.drawLine(
      center.translate(-25, 20),
      center.translate(-55, -22),
      limbPaint,
    );
    canvas.drawLine(
      center.translate(25, 20),
      center.translate(55, -22),
      limbPaint,
    );
    _circle(canvas, center.translate(-57, -25), 8, _skin);
    _circle(canvas, center.translate(57, -25), 8, _skin);

    _circle(canvas, center.translate(0, -27), 40, _skin);
    if (girl) {
      _circle(canvas, center.translate(-37, -30), 14, hair);
      _circle(canvas, center.translate(37, -30), 14, hair);
    }
    canvas.drawArc(
      Rect.fromCircle(center: center.translate(0, -32), radius: 40),
      math.pi,
      math.pi,
      true,
      Paint()..color = hair,
    );

    _happyFace(canvas, center.translate(0, -24));
  }

  void _lion(Canvas canvas, Offset center) {
    const mane = Color(0xFFF2A552);
    const fur = Color(0xFFFFCF79);

    _circle(canvas, center.translate(0, -23), 64, mane);
    _circle(canvas, center.translate(-40, -61), 16, mane);
    _circle(canvas, center.translate(40, -61), 16, mane);

    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 54), width: 88, height: 116),
      Paint()..color = fur,
    );
    final armPaint = Paint()
      ..color = fur
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(-30, 34),
      center.translate(-59, -6),
      armPaint,
    );
    canvas.drawLine(
      center.translate(30, 34),
      center.translate(59, -6),
      armPaint,
    );

    _circle(canvas, center.translate(0, -24), 48, fur);
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, -8), width: 43, height: 30),
      Paint()..color = const Color(0xFFFFE5AF),
    );
    _happyFace(canvas, center.translate(0, -25), lion: true);
  }

  void _happyFace(Canvas canvas, Offset center, {bool lion = false}) {
    _circle(canvas, center.translate(-14, -3), 4, _face);
    _circle(canvas, center.translate(14, -3), 4, _face);
    if (lion) {
      _circle(canvas, center.translate(0, 9), 5, const Color(0xFF8A6256));
    }
    canvas.drawArc(
      Rect.fromCenter(
        center: center.translate(0, lion ? 13 : 8),
        width: lion ? 21 : 23,
        height: 15,
      ),
      0,
      math.pi,
      false,
      Paint()
        ..color = _face
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _circle(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WordIconsPainter extends CustomPainter {
  const _WordIconsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 250, size.height / 170);
    canvas.save();
    canvas.translate(
      (size.width - 250 * scale) / 2,
      (size.height - 170 * scale) / 2,
    );
    canvas.scale(scale);

    _apple(canvas, const Offset(48, 78));
    _cat(canvas, const Offset(125, 93));
    _flower(canvas, const Offset(205, 80));

    canvas.restore();
  }

  void _apple(Canvas canvas, Offset center) {
    final apple = Paint()..color = const Color(0xFFF04F4F);
    canvas.drawCircle(center.translate(-13, 2), 25, apple);
    canvas.drawCircle(center.translate(13, 2), 25, apple);
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 14), width: 48, height: 48),
      apple,
    );
    canvas.drawLine(
      center.translate(0, -23),
      center.translate(6, -40),
      Paint()
        ..color = const Color(0xFF68452E)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(19, -31), width: 23, height: 12),
      Paint()..color = const Color(0xFF55B95A),
    );
    _face(canvas, center.translate(0, 5));
  }

  void _cat(Canvas canvas, Offset center) {
    final orange = Paint()..color = const Color(0xFFF7A94A);
    final head = Path()
      ..moveTo(center.dx - 31, center.dy - 22)
      ..lineTo(center.dx - 25, center.dy - 52)
      ..lineTo(center.dx - 4, center.dy - 34)
      ..lineTo(center.dx + 22, center.dy - 52)
      ..lineTo(center.dx + 31, center.dy - 20)
      ..quadraticBezierTo(
        center.dx + 35,
        center.dy + 22,
        center.dx,
        center.dy + 25,
      )
      ..quadraticBezierTo(
        center.dx - 35,
        center.dy + 22,
        center.dx - 31,
        center.dy - 22,
      )
      ..close();
    canvas.drawPath(head, orange);
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 37), width: 54, height: 60),
      orange,
    );
    _face(canvas, center.translate(0, -6));
    canvas.drawLine(
      center.translate(28, 36),
      center.translate(45, 18),
      Paint()
        ..color = orange.color
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
  }

  void _flower(Canvas canvas, Offset center) {
    canvas.drawLine(
      center.translate(0, 15),
      center.translate(0, 57),
      Paint()
        ..color = const Color(0xFF43AE5D)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    final petal = Paint()..color = const Color(0xFFFF83B4);
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      canvas.drawCircle(
        center.translate(math.cos(angle) * 22, math.sin(angle) * 22),
        17,
        petal,
      );
    }
    canvas.drawCircle(center, 19, Paint()..color = const Color(0xFFFFD34E));
    _face(canvas, center);
  }

  void _face(Canvas canvas, Offset center) {
    final dark = Paint()..color = const Color(0xFF503D43);
    canvas.drawCircle(center.translate(-8, -2), 3, dark);
    canvas.drawCircle(center.translate(8, -2), 3, dark);
    canvas.drawArc(
      Rect.fromCenter(center: center.translate(0, 4), width: 17, height: 13),
      0,
      math.pi,
      false,
      dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
