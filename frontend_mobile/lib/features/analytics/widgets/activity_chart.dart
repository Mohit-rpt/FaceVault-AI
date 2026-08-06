import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ActivityChart extends StatelessWidget {
  final List<double> data;
  final double height;

  const ActivityChart({super.key, required this.data, this.height = 150});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _BarChartPainter(data: data),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> data;
  _BarChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final barWidth = size.width / data.length - 8;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final barHeight = (data[i] / maxValue) * size.height * 0.9;
      final x = i * (size.width / data.length) + 4;
      final y = size.height - barHeight;

      // Gradient for each bar (neon effect)
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(4),
      );
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.neonCyan.withOpacity(0.8),
          AppTheme.neonCyan.withOpacity(0.2),
        ],
      ).createShader(rect.outerRect);

      canvas.drawRRect(rect, paint);

      // Glow on top of bar
      if (data[i] == maxValue) {
        final glowPaint = Paint()
          ..color = AppTheme.neonCyan.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawRRect(rect, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}