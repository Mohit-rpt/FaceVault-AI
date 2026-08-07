// lib/features/camera/widgets/recognition_overlay.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/camera/coordinate_transformer.dart';
import '../../../services/local_recognition/local_recognition_result.dart';

/// Overlay widget rendering futuristic glowing HUD bounding boxes and identity labels on camera preview.
class RecognitionOverlay extends StatelessWidget {
  final List<LocalRecognitionResult> recognitionResults;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;
  final double? cameraAspectRatio;

  const RecognitionOverlay({
    super.key,
    required this.recognitionResults,
    required this.lensDirection,
    required this.sensorOrientation,
    this.cameraAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = Size(constraints.maxWidth, constraints.maxHeight);

        return CustomPaint(
          size: previewSize,
          painter: _RecognitionPainter(
            results: recognitionResults,
            previewSize: previewSize,
            lensDirection: lensDirection,
            sensorOrientation: sensorOrientation,
            cameraAspectRatio: cameraAspectRatio,
          ),
        );
      },
    );
  }
}

class _RecognitionPainter extends CustomPainter {
  final List<LocalRecognitionResult> results;
  final Size previewSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;
  final double? cameraAspectRatio;

  _RecognitionPainter({
    required this.results,
    required this.previewSize,
    required this.lensDirection,
    required this.sensorOrientation,
    this.cameraAspectRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final res in results) {
      // 1. Transform normalized bounding box [0.0 - 1.0] to screen pixel coordinates
      final Rect rect = CoordinateTransformer.transformBox(
        normalizedBox: res.boundingBox,
        previewWidgetSize: previewSize,
        lensDirection: lensDirection,
        sensorOrientation: sensorOrientation,
        cameraAspectRatio: cameraAspectRatio,
      );

      final bool isKnown = res.isKnown;
      final Color strokeColor;
      if (res.isKnown) {
        strokeColor = AppTheme.neonGreen;
      } else if (res.state == 'confirmed' || res.state == 'active') {
        strokeColor = AppTheme.neonCyan; // Recognizing
      } else {
        strokeColor = const Color(0xFFFF6B35); // Warning orange for unknown
      }

      // 2. Draw Glowing Bounding Box
      final boxPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final glowPaint = Paint()
        ..color = strokeColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rrect, glowPaint);
      canvas.drawRRect(rrect, boxPaint);

      // 3. Draw Corner HUD Highlights
      _drawHudCorners(canvas, rect, strokeColor);

      // 4. Render Identity Text Tag Header
      final String labelText = isKnown
          ? '${res.displayName.toUpperCase()} (${(res.similarity * 100).toStringAsFixed(0)}%)'
          : 'UNKNOWN';

      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: isKnown ? Colors.black : Colors.white,
          fontSize: 11,
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final double tagWidth = textPainter.width + 16;
      final double tagHeight = textPainter.height + 6;
      final double tagLeft = rect.left;
      final double tagTop = (rect.top - tagHeight - 4).clamp(0.0, size.height - tagHeight);

      final tagBgPaint = Paint()
        ..color = isKnown ? AppTheme.neonGreen : Colors.black87
        ..style = PaintingStyle.fill;

      final tagBorderPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final tagRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tagLeft, tagTop, tagWidth, tagHeight),
        const Radius.circular(4),
      );

      canvas.drawRRect(tagRect, tagBgPaint);
      canvas.drawRRect(tagRect, tagBorderPaint);

      textPainter.paint(
        canvas,
        Offset(tagLeft + 8, tagTop + 3),
      );
    }
  }

  void _drawHudCorners(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    const cornerLength = 14.0;

    // Top-Left
    canvas.drawLine(rect.topLeft, Offset(rect.left + cornerLength, rect.top), paint);
    canvas.drawLine(rect.topLeft, Offset(rect.left, rect.top + cornerLength), paint);

    // Top-Right
    canvas.drawLine(rect.topRight, Offset(rect.right - cornerLength, rect.top), paint);
    canvas.drawLine(rect.topRight, Offset(rect.right, rect.top + cornerLength), paint);

    // Bottom-Left
    canvas.drawLine(rect.bottomLeft, Offset(rect.left + cornerLength, rect.bottom), paint);
    canvas.drawLine(rect.bottomLeft, Offset(rect.left, rect.bottom - cornerLength), paint);

    // Bottom-Right
    canvas.drawLine(rect.bottomRight, Offset(rect.right - cornerLength, rect.bottom), paint);
    canvas.drawLine(rect.bottomRight, Offset(rect.right, rect.bottom - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _RecognitionPainter oldDelegate) => true;
}
