import 'package:flutter/material.dart';

class AnimatedGuide extends StatefulWidget {
  const AnimatedGuide({
    super.key,
    required this.message,
    this.isTalking = false,
  });

  final String message;
  final bool isTalking;

  @override
  State<AnimatedGuide> createState() => _AnimatedGuideState();
}

class _AnimatedGuideState extends State<AnimatedGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFFBEB),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ScaleTransition(
              scale: Tween(begin: 1.0, end: widget.isTalking ? 1.08 : 1.03)
                  .animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeInOut,
                    ),
                  ),
              child: const Text('🦁', style: TextStyle(fontSize: 92)),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
