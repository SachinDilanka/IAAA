import 'package:flutter/material.dart';

class WaveformVisualizer extends StatelessWidget {
  final List<double> samples;
  final bool isListening;

  const WaveformVisualizer({
    super.key,
    required this.samples,
    required this.isListening,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isListening ? Colors.cyanAccent.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: CustomPaint(
        painter: WaveformPainter(
          samples: samples,
          isListening: isListening,
          color: isListening ? Colors.cyanAccent : Colors.grey,
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> samples;
  final bool isListening;
  final Color color;

  WaveformPainter({
    required this.samples,
    required this.isListening,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || !isListening) {
      final paint = Paint()
        ..color = Colors.grey.withOpacity(0.4)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final double step = size.width / samples.length;
    final double centerY = size.height / 2;

    for (int i = 0; i < samples.length; i++) {
      final double x = i * step;
      final double barHeight = samples[i] * (size.height / 2);
      canvas.drawLine(
        Offset(x, centerY - barHeight),
        Offset(x, centerY + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}

