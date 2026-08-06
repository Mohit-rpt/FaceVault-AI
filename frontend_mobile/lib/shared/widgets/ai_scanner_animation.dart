import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AiScannerAnimation extends StatefulWidget {
  final double size;
  const AiScannerAnimation({super.key, this.size = 150});

  @override
  State<AiScannerAnimation> createState() => _AiScannerAnimationState();
}

class _AiScannerAnimationState extends State<AiScannerAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _ScannerPainter(
            progress: _controller.value,
            color: AppTheme.neonCyan,
          ),
        );
      },
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScannerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Outer rings
    for (int i = 1; i <= 3; i++) {
      final ringRadius = radius * (0.5 + i * 0.15);
      final paint = Paint()
        ..color = color.withOpacity(0.2 - i * 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, ringRadius, paint);
    }

    // Rotating arc
    final sweepAngle = pi / 3;
    final startAngle = 2 * pi * progress;
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withOpacity(0.8),
          color.withOpacity(0.0),
        ],
        stops: const [0.2, 0.9],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.85),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // Center dot
    canvas.drawCircle(
      center,
      5,
      Paint()..color = color,
    );
    // Pulse
    final pulseRadius = 3 + sin(progress * 2 * pi) * 2;
    canvas.drawCircle(
      center,
      pulseRadius,
      Paint()..color = color.withOpacity(0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter oldDelegate) => true;
}