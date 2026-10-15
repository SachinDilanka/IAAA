import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../features/app/app_controller.dart';
import '../../l10n/l10n.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final progress = controller.progress;
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
            _ParkHero(
              stars: progress.stars,
              onStart: () => context.go(startRoute),
            ),
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
  const _ParkHero({required this.stars, required this.onStart});

  final int stars;
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
                left: compact ? 18 : 28,
                top: compact ? 18 : 24,
                right: compact ? 18 : 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.hello,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: const Color(0xFF25405F),
                            fontWeight: FontWeight.w900,
                            shadows: const [
                              Shadow(color: Colors.white, blurRadius: 8),
                            ],
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.welcomeMessage,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF3E6680),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: compact ? 104 : 24,
                right: compact ? 16 : 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFFE08A)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x22000000), blurRadius: 10),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.gold,
                        size: 25,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$stars ${context.l10n.stars}',
                        style: const TextStyle(
                          color: Color(0xFF684B10),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
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
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF80BD), Color(0xFFF43F8C)],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55D91F72),
                blurRadius: 18,
                offset: Offset(0, 9),
              ),
              BoxShadow(
                color: Color(0x66FFFFFF),
                blurRadius: 3,
                offset: Offset(0, -2),
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
                gradient: LinearGradient(colors: widget.background),
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
          shadows: [
            Shadow(
              color: color.withValues(alpha: .35),
              offset: const Offset(3, 5),
            ),
          ],
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

  @override
  void paint(Canvas canvas, Size size) {
    const designSize = Size(1000, 430);
    canvas.save();
    canvas.scale(
      size.width / designSize.width,
      size.height / designSize.height,
    );

    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFBDEEFF), Color(0xFFE9FBFF)],
      ).createShader(Offset.zero & designSize);
    canvas.drawRect(Offset.zero & designSize, sky);

    _circle(canvas, const Offset(875, 76), 45, const Color(0xFFFFD95A));
    _circle(canvas, const Offset(875, 76), 61, const Color(0x33FFE178));
    _cloud(canvas, 145, 82, .9);
    _cloud(canvas, 735, 116, .66);

    final farHill = Path()
      ..moveTo(0, 274)
      ..quadraticBezierTo(190, 180, 390, 270)
      ..quadraticBezierTo(630, 160, 1000, 265)
      ..lineTo(1000, 430)
      ..lineTo(0, 430)
      ..close();
    canvas.drawPath(farHill, Paint()..color = const Color(0xFF9FE47B));

    final grass = Path()
      ..moveTo(0, 315)
      ..quadraticBezierTo(250, 255, 500, 315)
      ..quadraticBezierTo(760, 250, 1000, 305)
      ..lineTo(1000, 430)
      ..lineTo(0, 430)
      ..close();
    canvas.drawPath(grass, Paint()..color = const Color(0xFF67CE69));

    _tree(canvas, const Offset(95, 238), 1.05);
    _tree(canvas, const Offset(908, 244), .95);
    _bush(canvas, const Offset(180, 322), .8);
    _bush(canvas, const Offset(816, 322), .72);

    _musicNote(canvas, const Offset(310, 130), const Color(0xFFF43F8C), 1.0);
    _musicNote(canvas, const Offset(685, 154), const Color(0xFF8B5CF6), .78);
    _musicNote(canvas, const Offset(744, 205), const Color(0xFFF97316), .6);
    _bubble(canvas, const Offset(256, 183), 13);
    _bubble(canvas, const Offset(785, 105), 10);
    _bubble(canvas, const Offset(830, 178), 16);

    _child(
      canvas,
      const Offset(355, 229),
      shirt: const Color(0xFF4DB7F4),
      girl: false,
    );
    _lion(canvas, const Offset(500, 226));
    _child(
      canvas,
      const Offset(645, 229),
      shirt: const Color(0xFFF472B6),
      girl: true,
    );

    _flower(canvas, const Offset(235, 352), const Color(0xFFFF7DAA));
    _flower(canvas, const Offset(752, 350), const Color(0xFFFFD34E));
    _flower(canvas, const Offset(858, 370), const Color(0xFFA78BFA));
    _butterfly(canvas, const Offset(142, 194));

    canvas.restore();
  }

  void _cloud(Canvas canvas, double x, double y, double scale) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .9);
    _circle(canvas, Offset(x, y), 28 * scale, paint.color);
    _circle(
      canvas,
      Offset(x + 32 * scale, y - 12 * scale),
      37 * scale,
      paint.color,
    );
    _circle(canvas, Offset(x + 70 * scale, y), 28 * scale, paint.color);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 4, y, 78 * scale, 24 * scale),
        Radius.circular(14 * scale),
      ),
      paint,
    );
  }

  void _tree(Canvas canvas, Offset base, double scale) {
    final trunk = Paint()..color = const Color(0xFFA9693C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: base.translate(0, -46 * scale),
          width: 28 * scale,
          height: 100 * scale,
        ),
        Radius.circular(12 * scale),
      ),
      trunk,
    );
    _circle(
      canvas,
      base.translate(-28 * scale, -100 * scale),
      45 * scale,
      const Color(0xFF32B85D),
    );
    _circle(
      canvas,
      base.translate(19 * scale, -116 * scale),
      55 * scale,
      const Color(0xFF45C969),
    );
    _circle(
      canvas,
      base.translate(51 * scale, -83 * scale),
      40 * scale,
      const Color(0xFF2EAF58),
    );
    _circle(
      canvas,
      base.translate(2 * scale, -70 * scale),
      45 * scale,
      const Color(0xFF52D174),
    );
  }

  void _bush(Canvas canvas, Offset base, double scale) {
    for (final point in const [Offset(-35, 0), Offset(0, -14), Offset(35, 2)]) {
      _circle(
        canvas,
        base + point * scale,
        34 * scale,
        const Color(0xFF36B85B),
      );
    }
  }

  void _child(
    Canvas canvas,
    Offset center, {
    required Color shirt,
    required bool girl,
  }) {
    final skin = Paint()..color = const Color(0xFFD98A5F);
    final outline = Paint()
      ..color = const Color(0xFF51352F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center.translate(-18, 65),
      center.translate(-27, 105),
      outline..strokeWidth = 12,
    );
    canvas.drawLine(
      center.translate(18, 65),
      center.translate(27, 105),
      outline,
    );
    canvas.drawCircle(
      center.translate(-29, 108),
      9,
      Paint()..color = const Color(0xFFFFF5DC),
    );
    canvas.drawCircle(
      center.translate(29, 108),
      9,
      Paint()..color = const Color(0xFFFFF5DC),
    );

    final body = Path()
      ..moveTo(center.dx - 30, center.dy + 10)
      ..quadraticBezierTo(
        center.dx,
        center.dy - 2,
        center.dx + 30,
        center.dy + 10,
      )
      ..lineTo(center.dx + 25, center.dy + 70)
      ..lineTo(center.dx - 25, center.dy + 70)
      ..close();
    canvas.drawPath(body, Paint()..color = shirt);
    canvas.drawLine(
      center.translate(-25, 20),
      center.translate(-58, 1),
      outline..strokeWidth = 10,
    );
    canvas.drawLine(
      center.translate(25, 20),
      center.translate(57, -4),
      outline,
    );
    canvas.drawCircle(center.translate(-61, -2), 7, skin);
    canvas.drawCircle(center.translate(60, -7), 7, skin);

    canvas.drawCircle(center.translate(0, -25), 39, skin);
    final hair = Paint()..color = const Color(0xFF46312C);
    canvas.drawArc(
      Rect.fromCircle(center: center.translate(0, -31), radius: 39),
      math.pi,
      math.pi,
      true,
      hair,
    );
    if (girl) {
      canvas.drawCircle(center.translate(-36, -19), 15, hair);
      canvas.drawCircle(center.translate(36, -19), 15, hair);
    }
    _eye(canvas, center.translate(-13, -25));
    _eye(canvas, center.translate(13, -25));
    canvas.drawArc(
      Rect.fromCenter(center: center.translate(0, -10), width: 23, height: 15),
      0,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF8B3D42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      center.translate(girl ? 42 : -42, -26),
      9,
      Paint()..color = shirt,
    );
  }

  void _lion(Canvas canvas, Offset center) {
    final mane = Paint()..color = const Color(0xFFF59E3F);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      canvas.drawCircle(
        center.translate(math.cos(angle) * 48, math.sin(angle) * 48 - 27),
        24,
        mane,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 48), width: 82, height: 112),
      Paint()..color = const Color(0xFFFFC866),
    );
    canvas.drawCircle(
      center.translate(0, -27),
      47,
      Paint()..color = const Color(0xFFFFD782),
    );
    canvas.drawCircle(center.translate(-35, -61), 14, mane);
    canvas.drawCircle(center.translate(35, -61), 14, mane);
    _eye(canvas, center.translate(-16, -31));
    _eye(canvas, center.translate(16, -31));
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, -10), width: 42, height: 29),
      Paint()..color = const Color(0xFFFFE8B0),
    );
    canvas.drawCircle(
      center.translate(0, -17),
      6,
      Paint()..color = const Color(0xFF6B4334),
    );
    canvas.drawArc(
      Rect.fromCenter(center: center.translate(0, -6), width: 22, height: 15),
      0,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF8B3D42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      center.translate(-28, 48),
      center.translate(-62, 21),
      Paint()
        ..color = const Color(0xFFFFC866)
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      center.translate(28, 48),
      center.translate(62, 19),
      Paint()
        ..color = const Color(0xFFFFC866)
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
  }

  void _eye(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 4.5, Paint()..color = const Color(0xFF27364A));
    canvas.drawCircle(
      center.translate(-1.3, -1.5),
      1.3,
      Paint()..color = Colors.white,
    );
  }

  void _flower(Canvas canvas, Offset center, Color color) {
    final petal = Paint()..color = color;
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5;
      canvas.drawCircle(
        center.translate(math.cos(angle) * 9, math.sin(angle) * 9),
        7,
        petal,
      );
    }
    canvas.drawCircle(center, 6, Paint()..color = const Color(0xFFFFE45E));
  }

  void _butterfly(Canvas canvas, Offset center) {
    final paint = Paint()..color = const Color(0xFFFF8A65);
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(-7, 0), width: 13, height: 20),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(7, 0), width: 13, height: 20),
      paint,
    );
    canvas.drawCircle(center, 3, Paint()..color = const Color(0xFF5B4636));
  }

  void _bubble(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      center.translate(-radius * .3, -radius * .3),
      2,
      Paint()..color = Colors.white,
    );
  }

  void _musicNote(Canvas canvas, Offset center, Color color, double scale) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, center.translate(0, -31 * scale), paint);
    canvas.drawLine(
      center.translate(0, -31 * scale),
      center.translate(18 * scale, -26 * scale),
      paint,
    );
    canvas.drawCircle(center.translate(-6 * scale, 2), 8 * scale, paint);
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
