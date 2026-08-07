// lib/services/camera/coordinate_transformer.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Utility for transforming bounding boxes between Camera Image space, Sensor rotation, and UI Preview widget space.
class CoordinateTransformer {
  /// Transform normalized bounding box [left, top, right, bottom] (0.0 to 1.0) to UI Screen Rect.
  ///
  /// Supports [cameraAspectRatio] (e.g. portrait aspect ratio 1.0 / controller.aspectRatio)
  /// to accurately map coordinates when camera preview uses BoxFit.cover scaling.
  static Rect transformBox({
    required List<double> normalizedBox,
    required Size previewWidgetSize,
    required CameraLensDirection lensDirection,
    required int sensorOrientation,
    double? cameraAspectRatio,
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

    double renderedWidth = screenWidth;
    double renderedHeight = screenHeight;
    double dx = 0.0;
    double dy = 0.0;

    if (cameraAspectRatio != null && cameraAspectRatio > 0 && screenHeight > 0) {
      final double screenAR = screenWidth / screenHeight;

      if (cameraAspectRatio > screenAR) {
        // Camera preview is wider than screen: height fits screen, width overflows left & right
        renderedHeight = screenHeight;
        renderedWidth = screenHeight * cameraAspectRatio;
        dx = (screenWidth - renderedWidth) / 2.0;
        dy = 0.0;
      } else {
        // Camera preview is taller than screen: width fits screen, height overflows top & bottom
        renderedWidth = screenWidth;
        renderedHeight = screenWidth / cameraAspectRatio;
        dx = 0.0;
        dy = (screenHeight - renderedHeight) / 2.0;
      }
    }

    final double pixelLeft = (left * renderedWidth + dx).clamp(0.0, screenWidth);
    final double pixelTop = (top * renderedHeight + dy).clamp(0.0, screenHeight);
    final double pixelRight = (right * renderedWidth + dx).clamp(0.0, screenWidth);
    final double pixelBottom = (bottom * renderedHeight + dy).clamp(0.0, screenHeight);

    return Rect.fromLTRB(pixelLeft, pixelTop, pixelRight, pixelBottom);
  }
}

