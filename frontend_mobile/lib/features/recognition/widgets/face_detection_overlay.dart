import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class FaceDetectionOverlay extends StatefulWidget {
  final bool isDetected;
  final double confidence; // 0-100

  const FaceDetectionOverlay({
    super.key,
    required this.isDetected,
    this.confidence = 0,
  });

  @override
  State<FaceDetectionOverlay> createState() => _FaceDetectionOverlayState();
}

class _FaceDetectionOverlayState extends State<FaceDetectionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _opacityAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) => CustomPaint(
        size: const Size(220, 270), // face bounding box size
        painter: _HudPainter(
          opacity: _opacityAnimation.value,
          isDetected: widget.isDetected,
          confidence: widget.confidence,
        ),
      ),
    );
  }
}

class _HudPainter extends CustomPainter {
  final double opacity;
  final bool isDetected;
  final double confidence;

  _HudPainter({
    required this.opacity,
    required this.isDetected,
    required this.confidence,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.neonCyan.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Bounding rectangle
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, paint);

    // HUD corners - each corner is two lines
    final cornerLength = 30.0;
    final linePaint = Paint()
      ..color = AppTheme.neonCyan.withOpacity(opacity * 0.9)
      ..strokeWidth = 3;

    // Top-left corner
    canvas.drawLine(Offset(0, cornerLength), Offset(0, 0), linePaint);
    canvas.drawLine(Offset(0, 0), Offset(cornerLength, 0), linePaint);

    // Top-right
    canvas.drawLine(Offset(size.width - cornerLength, 0),
        Offset(size.width, 0), linePaint);
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width, cornerLength), linePaint);

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height - cornerLength),
        Offset(size.width, size.height), linePaint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - cornerLength, size.height), linePaint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height - cornerLength),
        Offset(0, size.height), linePaint);
    canvas.drawLine(Offset(0, size.height),
        Offset(cornerLength, size.height), linePaint);

    // Central face cross (if detected)
    if (isDetected) {
      final center = Offset(size.width / 2, size.height / 2);
      final crossPaint = Paint()
        ..color = AppTheme.neonGreen.withOpacity(opacity)
        ..strokeWidth = 1.5;
      canvas.drawLine(
          Offset(center.dx - 20, center.dy), Offset(center.dx + 20, center.dy),
          crossPaint);
      canvas.drawLine(
          Offset(center.dx, center.dy - 20), Offset(center.dx, center.dy + 20),
          crossPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HudPainter oldDelegate) => true;
}