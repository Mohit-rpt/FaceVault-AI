import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class DetectorTensorResult {
  final Float32List tensor;
  final double scaleRatio;
  final int padX;
  final int padY;
  final int originalWidth;
  final int originalHeight;

  DetectorTensorResult({
    required this.tensor,
    required this.scaleRatio,
    required this.padX,
    required this.padY,
    required this.originalWidth,
    required this.originalHeight,
  });
}

class RgbBytesResult {
  final Uint8List rgbBytes;
  final int width;
  final int height;

  RgbBytesResult({
    required this.rgbBytes,
    required this.width,
    required this.height,
  });
}

/// Efficient converter for converting raw camera frame buffers (YUV420_888 / BGRA8888) to normalized RGB Float32List.
class ImageConverter {
  static DetectorTensorResult convertCameraImageToDetectorTensor(
    CameraImage image, {
    int targetSize = 640,
    int sensorOrientation = 90,
  }) {
    final int origW = image.width;
    final int origH = image.height;
    
    final bool isRotated = sensorOrientation == 90 || sensorOrientation == 270;
    final int rotW = isRotated ? origH : origW;
    final int rotH = isRotated ? origW : origH;

    final double scaleRatio = math.min(targetSize / rotW, targetSize / rotH);
    final int newW = (rotW * scaleRatio).round();
    final int newH = (rotH * scaleRatio).round();
    
    final int padX = (targetSize - newW) ~/ 2;
    final int padY = (targetSize - newH) ~/ 2;

    final Float32List tensor = Float32List(1 * 3 * targetSize * targetSize);
    
    if (image.format.group == ImageFormatGroup.yuv420 && image.planes.length >= 3) {
      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];

      final int yRowStride = yPlane.bytesPerRow;
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

      final int planeSize = targetSize * targetSize;

      for (int dy = 0; dy < newH; dy++) {
        for (int dx = 0; dx < newW; dx++) {
          final int rx = (dx / scaleRatio).floor().clamp(0, rotW - 1);
          final int ry = (dy / scaleRatio).floor().clamp(0, rotH - 1);

          int srcX = rx;
          int srcY = ry;

          if (sensorOrientation == 90) {
            srcX = ry;
            srcY = origH - 1 - rx;
          } else if (sensorOrientation == 270) {
            srcX = origW - 1 - ry;
            srcY = rx;
          } else if (sensorOrientation == 180) {
            srcX = origW - 1 - rx;
            srcY = origH - 1 - ry;
          }

          final int yIndex = srcY * yRowStride + srcX;
          final int uvX = srcX ~/ 2;
          final int uvY = srcY ~/ 2;
          final int uvIndex = uvY * uvRowStride + (uvX * uvPixelStride);

          final int yValue = yPlane.bytes[yIndex] & 0xFF;
          final int uValue = uPlane.bytes[uvIndex] & 0xFF;
          final int vValue = vPlane.bytes[uvIndex] & 0xFF;

          final int r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
          final int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round().clamp(0, 255);
          final int b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);

          final int outX = padX + dx;
          final int outY = padY + dy;
          final int outIdx = outY * targetSize + outX;

          tensor[0 * planeSize + outIdx] = (r - 127.5) / 127.5; // Red
          tensor[1 * planeSize + outIdx] = (g - 127.5) / 127.5; // Green
          tensor[2 * planeSize + outIdx] = (b - 127.5) / 127.5; // Blue
        }
      }
    }
    
    return DetectorTensorResult(
      tensor: tensor,
      scaleRatio: scaleRatio,
      padX: padX,
      padY: padY,
      originalWidth: rotW,
      originalHeight: rotH,
    );
  }

  static RgbBytesResult convertCameraImageToRgbBytes(
    CameraImage image, {
    int sensorOrientation = 90,
  }) {
    final int origW = image.width;
    final int origH = image.height;
    
    final bool isRotated = sensorOrientation == 90 || sensorOrientation == 270;
    final int rotW = isRotated ? origH : origW;
    final int rotH = isRotated ? origW : origH;

    final Uint8List rgbBytes = Uint8List(rotW * rotH * 3);

    if (image.format.group == ImageFormatGroup.yuv420 && image.planes.length >= 3) {
      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];

      final int yRowStride = yPlane.bytesPerRow;
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

      for (int ry = 0; ry < rotH; ry++) {
        for (int rx = 0; rx < rotW; rx++) {
          int srcX = rx;
          int srcY = ry;

          if (sensorOrientation == 90) {
            srcX = ry;
            srcY = origH - 1 - rx;
          } else if (sensorOrientation == 270) {
            srcX = origW - 1 - ry;
            srcY = rx;
          } else if (sensorOrientation == 180) {
            srcX = origW - 1 - rx;
            srcY = origH - 1 - ry;
          }

          final int yIndex = srcY * yRowStride + srcX;
          final int uvX = srcX ~/ 2;
          final int uvY = srcY ~/ 2;
          final int uvIndex = uvY * uvRowStride + (uvX * uvPixelStride);

          final int yValue = yPlane.bytes[yIndex] & 0xFF;
          final int uValue = uPlane.bytes[uvIndex] & 0xFF;
          final int vValue = vPlane.bytes[uvIndex] & 0xFF;

          final int r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
          final int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round().clamp(0, 255);
          final int b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);

          final int outIdx = (ry * rotW + rx) * 3;
          rgbBytes[outIdx] = r;
          rgbBytes[outIdx + 1] = g;
          rgbBytes[outIdx + 2] = b;
        }
      }
    }

    return RgbBytesResult(
      rgbBytes: rgbBytes,
      width: rotW,
      height: rotH,
    );
  }
}
