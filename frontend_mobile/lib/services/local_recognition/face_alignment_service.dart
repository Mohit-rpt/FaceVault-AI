// lib/services/local_recognition/face_alignment_service.dart

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Production Face Alignment Service.
///
/// Maps 5 SCRFD facial landmarks (left eye, right eye, nose, left mouth, right mouth)
/// to standard InsightFace 112x112 canonical template coordinates using 2D similarity transform.
class FaceAlignmentService {
  static const int targetSize = 112;

  /// InsightFace canonical 5-landmark template for 112x112 face images
  static const List<List<double>> defaultTargetLandmarks = [
    [38.2946, 51.6963], // Left eye
    [73.5318, 51.5014], // Right eye
    [56.0252, 71.7366], // Nose
    [41.5493, 92.3655], // Left mouth corner
    [70.7299, 92.2041], // Right mouth corner
  ];

  /// Estimate 2x3 Similarity Affine Transformation Matrix M [a, -b, tx; b, a, ty]
  /// mapping source landmarks (src) to canonical target landmarks (dst).
  static List<double>? estimatePartialAffineMatrix(
    List<List<double>> srcLandmarks, {
    List<List<double>> dstLandmarks = defaultTargetLandmarks,
  }) {
    if (srcLandmarks.length < 5 || dstLandmarks.length < 5) {
      return null;
    }

    try {
      // Build linear system A (10x4) and B (10x1) for parameter vector [a, b, tx, ty]^T
      double sumX = 0, sumY = 0, sumU = 0, sumV = 0;

      for (int i = 0; i < 5; i++) {
        sumX += srcLandmarks[i][0];
        sumY += srcLandmarks[i][1];
        sumU += dstLandmarks[i][0];
        sumV += dstLandmarks[i][1];
      }

      // Closed-form solution for similarity transform (scale, rotation, translation)
      final double meanX = sumX / 5.0;
      final double meanY = sumY / 5.0;
      final double meanU = sumU / 5.0;
      final double meanV = sumV / 5.0;

      double varX = 0.0;
      double covXU = 0.0, covXV = 0.0, covYU = 0.0, covYV = 0.0;

      for (int i = 0; i < 5; i++) {
        final double dx = srcLandmarks[i][0] - meanX;
        final double dy = srcLandmarks[i][1] - meanY;
        final double du = dstLandmarks[i][0] - meanU;
        final double dv = dstLandmarks[i][1] - meanV;

        varX += dx * dx + dy * dy;
        covXU += dx * du;
        covXV += dx * dv;
        covYU += dy * du;
        covYV += dy * dv;
      }

      if (varX == 0.0) return null;

      final double a = (covXU + covYV) / varX;
      final double b = (covXV - covYU) / varX;

      final double tx = meanU - (a * meanX - b * meanY);
      final double ty = meanV - (b * meanX + a * meanY);

      // Return 2x3 transform matrix elements [m00, m01, m02, m10, m11, m12]
      return [a, -b, tx, b, a, ty];
    } catch (e) {
      debugPrint('⚠️ [FaceAlignment] Transform error: $e');
      return null;
    }
  }

  /// Align face crop from RGB image bytes and landmarks to 112x112 NCHW Float32List tensor.
  static Float32List alignFaceToRgbTensor({
    required Uint8List srcRgbBytes,
    required int srcWidth,
    required int srcHeight,
    required List<List<double>> landmarks,
  }) {
    final Float32List tensor = Float32List(1 * 3 * targetSize * targetSize);
    final int planeSize = targetSize * targetSize;

    final List<double>? matrix = estimatePartialAffineMatrix(landmarks);

    // Fallback: simple center crop if affine transform matrix fails
    if (matrix == null) {
      return _fallbackCenterCrop(srcRgbBytes, srcWidth, srcHeight);
    }

    final double a = matrix[0];
    final double minusB = matrix[1];
    final double tx = matrix[2];
    final double b = matrix[3];
    final double a2 = matrix[4];
    final double ty = matrix[5];

    // Compute inverse transform to sample pixels from source image (dst -> src)
    final double det = a * a2 - minusB * b;
    if (det == 0.0) {
      return _fallbackCenterCrop(srcRgbBytes, srcWidth, srcHeight);
    }

    final double invA = a2 / det;
    final double invMinusB = -minusB / det;
    final double invB = -b / det;
    final double invA2 = a / det;

    for (int y = 0; y < targetSize; y++) {
      for (int x = 0; x < targetSize; x++) {
        // Map destination pixel (x, y) back to source image coordinate (srcX, srcY)
        final double dx = x.toDouble() - tx;
        final double dy = y.toDouble() - ty;

        final double srcXF = invA * dx + invMinusB * dy;
        final double srcYF = invB * dx + invA2 * dy;

        final int srcX = math.max(0, math.min(srcWidth - 1, srcXF.round()));
        final int srcY = math.max(0, math.min(srcHeight - 1, srcYF.round()));

        final int srcPixelIdx = (srcY * srcWidth + srcX) * 3;

        double r = 127.5;
        double g = 127.5;
        double bVal = 127.5;

        if (srcPixelIdx + 2 < srcRgbBytes.length) {
          r = srcRgbBytes[srcPixelIdx + 0].toDouble();
          g = srcRgbBytes[srcPixelIdx + 1].toDouble();
          bVal = srcRgbBytes[srcPixelIdx + 2].toDouble();
        }

        final int planeIdx = y * targetSize + x;
        tensor[0 * planeSize + planeIdx] = (r - 127.5) / 127.5;
        tensor[1 * planeSize + planeIdx] = (g - 127.5) / 127.5;
        tensor[2 * planeSize + planeIdx] = (bVal - 127.5) / 127.5;
      }
    }

    return tensor;
  }

  static Float32List _fallbackCenterCrop(Uint8List srcBytes, int width, int height) {
    final Float32List tensor = Float32List(1 * 3 * targetSize * targetSize);
    final int planeSize = targetSize * targetSize;
    final double scaleX = width / targetSize;
    final double scaleY = height / targetSize;

    for (int y = 0; y < targetSize; y++) {
      final int srcY = math.min((y * scaleY).toInt(), height - 1);
      for (int x = 0; x < targetSize; x++) {
        final int srcX = math.min((x * scaleX).toInt(), width - 1);
        final int idx = (srcY * width + srcX) * 3;

        double r = 127.5, g = 127.5, b = 127.5;
        if (idx + 2 < srcBytes.length) {
          r = srcBytes[idx + 0].toDouble();
          g = srcBytes[idx + 1].toDouble();
          b = srcBytes[idx + 2].toDouble();
        }

        final int planeIdx = y * targetSize + x;
        tensor[0 * planeSize + planeIdx] = (r - 127.5) / 127.5;
        tensor[1 * planeSize + planeIdx] = (g - 127.5) / 127.5;
        tensor[2 * planeSize + planeIdx] = (b - 127.5) / 127.5;
      }
    }
    return tensor;
  }
}
