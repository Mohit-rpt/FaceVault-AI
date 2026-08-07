// lib/services/camera/coordinate_transformer.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Utility for transforming bounding boxes between Camera Image space, Sensor rotation, and UI Preview widget space.
class CoordinateTransformer {
  /// Transform normalized bounding box [left, top, right, bottom] (0.0 to 1.0) to UI Screen Rect.
  static Rect transformBox({
    required List<double> normalizedBox,
    required Size previewWidgetSize,
    required CameraLensDirection lensDirection,
    required int sensorOrientation,
  }) {
    if (normalizedBox.length < 4) {
      return Rect.zero;
    }

    double left = normalizedBox[0];
    double top = normalizedBox[1];
    double right = normalizedBox[2];
    double bottom = normalizedBox[3];

    // Front camera horizontal mirroring
    if (lensDirection == CameraLensDirection.front) {
      final double tempLeft = left;
      left = 1.0 - right;
      right = 1.0 - tempLeft;
    }

    final double screenWidth = previewWidgetSize.width;
    final double screenHeight = previewWidgetSize.height;

    final double pixelLeft = (left * screenWidth).clamp(0.0, screenWidth);
    final double pixelTop = (top * screenHeight).clamp(0.0, screenHeight);
    final double pixelRight = (right * screenWidth).clamp(0.0, screenWidth);
    final double pixelBottom = (bottom * screenHeight).clamp(0.0, screenHeight);

    return Rect.fromLTRB(
      pixelLeft,
      pixelTop,
      pixelRight,
      pixelBottom,
    );
  }
}
