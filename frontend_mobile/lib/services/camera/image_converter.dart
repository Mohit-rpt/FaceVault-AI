// lib/services/camera/image_converter.dart

import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Efficient converter for converting raw camera frame buffers (YUV420_888 / BGRA8888) to normalized RGB Float32List.
class ImageConverter {
  /// Convert CameraImage (YUV420_888 or BGRA8888) to normalized NCHW RGB Float32List tensor [-1.0, 1.0].
  static Float32List convertCameraImageToRgbTensor(
    CameraImage image, {
    int targetWidth = 112,
    int targetHeight = 112,
  }) {
    final Float32List tensor = Float32List(1 * 3 * targetHeight * targetWidth);
    final int planeSize = targetHeight * targetWidth;

    try {
      if (image.format.group == ImageFormatGroup.yuv420 && image.planes.length >= 3) {
        final Plane yPlane = image.planes[0];
        final Plane uPlane = image.planes[1];
        final Plane vPlane = image.planes[2];

        final int yRowStride = yPlane.bytesPerRow;
        final int uvRowStride = uPlane.bytesPerRow;
        final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

        final double scaleX = image.width / targetWidth;
        final double scaleY = image.height / targetHeight;

        for (int y = 0; y < targetHeight; y++) {
          final int srcY = math.min((y * scaleY).toInt(), image.height - 1);
          final int uvY = srcY ~/ 2;

          for (int x = 0; x < targetWidth; x++) {
            final int srcX = math.min((x * scaleX).toInt(), image.width - 1);
            final int uvX = srcX ~/ 2;

            final int yIndex = srcY * yRowStride + srcX;
            final int uvIndex = uvY * uvRowStride + (uvX * uvPixelStride);

            final int yValue = yPlane.bytes[yIndex] & 0xFF;
            final int uValue = uPlane.bytes[uvIndex] & 0xFF;
            final int vValue = vPlane.bytes[uvIndex] & 0xFF;

            // YUV to RGB Conversion Formula
            final double yF = yValue.toDouble();
            final double uF = uValue.toDouble() - 128.0;
            final double vF = vValue.toDouble() - 128.0;

            final double r = (yF + 1.402 * vF).clamp(0.0, 255.0);
            final double g = (yF - 0.344136 * uF - 0.714136 * vF).clamp(0.0, 255.0);
            final double b = (yF + 1.772 * uF).clamp(0.0, 255.0);

            final int planeIdx = y * targetWidth + x;
            tensor[0 * planeSize + planeIdx] = (r - 127.5) / 127.5; // Red
            tensor[1 * planeSize + planeIdx] = (g - 127.5) / 127.5; // Green
            tensor[2 * planeSize + planeIdx] = (b - 127.5) / 127.5; // Blue
          }
        }
      } else if (image.format.group == ImageFormatGroup.bgra8888 && image.planes.isNotEmpty) {
        final Plane plane = image.planes[0];
        final int rowStride = plane.bytesPerRow;
        final double scaleX = image.width / targetWidth;
        final double scaleY = image.height / targetHeight;

        for (int y = 0; y < targetHeight; y++) {
          final int srcY = math.min((y * scaleY).toInt(), image.height - 1);
          for (int x = 0; x < targetWidth; x++) {
            final int srcX = math.min((x * scaleX).toInt(), image.width - 1);
            final int pixelIdx = srcY * rowStride + (srcX * 4);

            final int bValue = plane.bytes[pixelIdx + 0] & 0xFF;
            final int gValue = plane.bytes[pixelIdx + 1] & 0xFF;
            final int rValue = plane.bytes[pixelIdx + 2] & 0xFF;

            final int planeIdx = y * targetWidth + x;
            tensor[0 * planeSize + planeIdx] = (rValue - 127.5) / 127.5;
            tensor[1 * planeSize + planeIdx] = (gValue - 127.5) / 127.5;
            tensor[2 * planeSize + planeIdx] = (bValue - 127.5) / 127.5;
          }
        }
      } else {
        // Fallback synthetic tensor
        for (int i = 0; i < tensor.length; i++) {
          tensor[i] = ((i % 256) - 127.5) / 127.5;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ImageConverter] Conversion warning: $e');
    }

    return tensor;
  }
}
