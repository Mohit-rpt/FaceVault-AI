import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AiScanningAnimation extends StatefulWidget {
  final double size;
  const AiScanningAnimation({super.key, this.size = 200});

  @override
  State<AiScanningAnimation> createState() => _AiScanningAnimationState();
}

class _AiScanningAnimationState extends State<AiScanningAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
      builder: (context, child) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _ScannerPainter(progress: _controller.value),
      ),
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double progress;
  _ScannerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 8;

    // Radar concentric circles (pulsing)
    for (int i = 1; i <= 3; i++) {
      final radius = maxRadius * (0.4 + i * 0.2);
      final pulse = sin(progress * 2 * pi * 2) * 3; // small pulse offset
      final paint = Paint()
        ..color = AppTheme.neonCyan.withOpacity(0.15 - i * 0.03)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius + pulse, paint);
    }

    // Rotating radar arm
    final armPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          AppTheme.neonCyan.withOpacity(0.8),
          AppTheme.neonCyan.withOpacity(0.0),
        ],
        stops: const [0.1, 0.5],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;
    final armPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: maxRadius),
          -pi / 2 + 2 * pi * progress, pi / 2, false)
      ..close();
    canvas.drawPath(armPath, armPaint);

    // Moving horizontal scan line
    final lineY = center.dy - maxRadius + (progress * 2 * maxRadius) % (2 * maxRadius);
    final linePaint = Paint()
      ..color = AppTheme.neonCyan.withOpacity(0.9)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(center.dx - maxRadius, lineY),
      Offset(center.dx + maxRadius, lineY),
      linePaint,
    );

    // Center dot pulse
    final dotRadius = 4 + sin(progress * 2 * pi * 4) * 2;
    canvas.drawCircle(center, dotRadius, Paint()..color = AppTheme.neonCyan);
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter oldDelegate) => true;
}