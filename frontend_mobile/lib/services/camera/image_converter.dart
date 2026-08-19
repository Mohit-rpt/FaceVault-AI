import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class DetectorTensorResult {
  final Float32List tensor;
  final Uint8List rgbBytes;
  final double scaleRatio;
  final int padX;
  final int padY;
  final int originalWidth;
  final int originalHeight;
  final int conversionTimeMs;

  DetectorTensorResult({
    required this.tensor,
    required this.rgbBytes,
    required this.scaleRatio,
    required this.padX,
    required this.padY,
    required this.originalWidth,
    required this.originalHeight,
    required this.conversionTimeMs,
  });
}

/// Single-pass YUV420 to NCHW tensor + HWC RGB converter.
/// Optimized for mobile ARM (320x320 target).
class ImageConverter {
  // Throttled logging
  static DateTime _lastLogTime = DateTime.fromMillisecondsSinceEpoch(0);

  static DetectorTensorResult convertRawYuvToDetectorTensor({
    required Uint8List yBuffer,
    required Uint8List uBuffer,
    required Uint8List vBuffer,
    required int yRowStride,
    required int uvRowStride,
    required int uvPixelStride,
    required int origW,
    required int origH,
    int targetSize = 640,
    int sensorOrientation = 90,
    Float32List? reuseTensor,
    Uint8List? reuseRgbBytes,
  }) {
    final Stopwatch sw = Stopwatch()..start();

    final bool isRotated = sensorOrientation == 90 || sensorOrientation == 270;
    final int rotW = isRotated ? origH : origW;
    final int rotH = isRotated ? origW : origH;

    final double scaleRatio = math.min(targetSize / rotW, targetSize / rotH);
    final int newW = (rotW * scaleRatio).round();
    final int newH = (rotH * scaleRatio).round();

    final int padX = (targetSize - newW) ~/ 2;
    final int padY = (targetSize - newH) ~/ 2;

    // Throttled preprocessing log
    final now = DateTime.now();
    if (now.difference(_lastLogTime).inMilliseconds >= 1000) {
      _lastLogTime = now;
      debugPrint('[YUV] sensorOr=$sensorOrientation orig=${origW}x$origH rot=${rotW}x$rotH scale=${scaleRatio.toStringAsFixed(3)} pad=$padX,$padY');
    }

    final int planeSize = targetSize * targetSize;
    final int requiredTensorSize = 1 * 3 * planeSize;
    final int requiredRgbSize = planeSize * 3;

    final Float32List tensor = (reuseTensor != null && reuseTensor.length == requiredTensorSize)
        ? reuseTensor
        : Float32List(requiredTensorSize);

    final Uint8List rgbBytes = (reuseRgbBytes != null && reuseRgbBytes.length == requiredRgbSize)
        ? reuseRgbBytes
        : Uint8List(requiredRgbSize);

    // Pad fill only if padding is actually present
    if (padX > 0 || padY > 0) {
      // Pad fill: normalized 0.0 (corresponds to pixel 127.5)
      rgbBytes.fillRange(0, rgbBytes.length, 127);
      // Ensure Float32List padding is also zeroed out if it's being reused, 
      // since the active area doesn't overwrite the padding zone.
      if (reuseTensor != null) {
        tensor.fillRange(0, tensor.length, 0.0);
      }
    }

      // Precalculate rx lookup for X dimension
      final Int32List rxTable = Int32List(newW);
      for (int dx = 0; dx < newW; dx++) {
        rxTable[dx] = (dx / scaleRatio).floor().clamp(0, rotW - 1);
      }

      for (int dy = 0; dy < newH; dy++) {
        final int ry = (dy / scaleRatio).floor().clamp(0, rotH - 1);
        final int outY = padY + dy;
        final int outRowOffset = outY * targetSize;

        for (int dx = 0; dx < newW; dx++) {
          final int rx = rxTable[dx];

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
          final int uvX = srcX >> 1;
          final int uvY = srcY >> 1;
          final int uvIndex = uvY * uvRowStride + (uvX * uvPixelStride);

          final int yValue = yBuffer[yIndex];
          final int uValue = uBuffer[uvIndex];
          final int vValue = vBuffer[uvIndex];

          // Fast integer YUV to RGB
          final int c = yValue - 16;
          final int d = uValue - 128;
          final int e = vValue - 128;

          final int r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
          final int g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
          final int b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

          final int outIdx = outRowOffset + (padX + dx);

          // NCHW Float32List normalized [-1.0, 1.0]
          tensor[outIdx] = (r - 127.5) * 0.007843137;
          tensor[planeSize + outIdx] = (g - 127.5) * 0.007843137;
          tensor[2 * planeSize + outIdx] = (b - 127.5) * 0.007843137;

          // HWC Uint8List for face alignment
          final int rawRgbIdx = outIdx * 3;
          rgbBytes[rawRgbIdx] = r;
          rgbBytes[rawRgbIdx + 1] = g;
          rgbBytes[rawRgbIdx + 2] = b;
        }
      }

    sw.stop();

    return DetectorTensorResult(
      tensor: tensor,
      rgbBytes: rgbBytes,
      scaleRatio: scaleRatio,
      padX: padX,
      padY: padY,
      originalWidth: rotW,
      originalHeight: rotH,
      conversionTimeMs: sw.elapsedMilliseconds,
    );
  }
}
