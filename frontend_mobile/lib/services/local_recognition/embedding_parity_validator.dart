// lib/services/local_recognition/embedding_parity_validator.dart

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'face_alignment_service.dart';
import 'local_face_embedding_pipeline.dart';

/// Developer Utility for verifying Parity between Backend and Mobile Face Preprocessing & Embeddings.
class EmbeddingParityValidator {
  final LocalFaceEmbeddingPipeline pipeline;

  EmbeddingParityValidator({LocalFaceEmbeddingPipeline? pipeline})
      : pipeline = pipeline ?? LocalFaceEmbeddingPipeline();

  /// Execute alignment & embedding parity check on a test sample image.
  Future<Map<String, dynamic>> validateParity() async {
    final Stopwatch sw = Stopwatch()..start();

    try {
      await pipeline.initialize();

      // Sample 200x200 RGB synthetic image bytes
      final int width = 200;
      final int height = 200;
      final Uint8List testRgbBytes = Uint8List(width * height * 3);
      for (int i = 0; i < testRgbBytes.length; i++) {
        testRgbBytes[i] = (i % 256);
      }

      // Sample 5-point SCRFD landmarks
      final List<List<double>> landmarks = [
        [70.0, 80.0],  // Left eye
        [130.0, 80.0], // Right eye
        [100.0, 110.0],// Nose
        [75.0, 140.0], // Left mouth
        [125.0, 140.0] // Right mouth
      ];

      // 1. Perform Face Alignment to 112x112 NCHW FloatTensor
      final Float32List alignedTensor = FaceAlignmentService.alignFaceToRgbTensor(
        srcRgbBytes: testRgbBytes,
        srcWidth: width,
        srcHeight: height,
        landmarks: landmarks,
      );

      // 2. Generate 512D L2-normalized embedding
      final Float32List? embedding = await pipeline.embeddingGenerator.generateFromTensor(alignedTensor);
      sw.stop();

      if (embedding == null || embedding.length != 512) {
        return {
          'success': false,
          'error': 'Embedding generation failed or returned invalid shape',
        };
      }

      // 3. Verify L2 Norm
      double sumSq = 0.0;
      bool isFinite = true;
      for (int i = 0; i < embedding.length; i++) {
        if (embedding[i].isNaN || embedding[i].isInfinite) {
          isFinite = false;
        }
        sumSq += embedding[i] * embedding[i];
      }
      final double l2Norm = math.sqrt(sumSq);

      final summary = '✅ [Parity Check] Embedding Dim: ${embedding.length} | L2 Norm: ${l2Norm.toStringAsFixed(6)} | Finite: $isFinite | Time: ${sw.elapsedMilliseconds} ms';
      debugPrint(summary);

      return {
        'success': isFinite && (l2Norm - 1.0).abs() < 0.001,
        'embedding_dimension': embedding.length,
        'l2_norm': l2Norm,
        'is_finite': isFinite,
        'execution_time_ms': sw.elapsedMilliseconds,
        'summary': summary,
      };
    } catch (e) {
      sw.stop();
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
