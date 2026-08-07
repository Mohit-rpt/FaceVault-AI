// lib/services/local_recognition/local_face_embedding_pipeline.dart

import 'package:flutter/foundation.dart';
import '../camera/mobile_face_detector.dart';
import 'embedding_generator.dart';
import 'face_alignment_service.dart';
import 'model_loader.dart';

/// Structure representing a detected, aligned, and embedded face in a frame.
///
/// Strictly NO identity assignment or recognition matching in Phase 3B-2A.
class LocalFaceEmbeddingResult {
  final int faceIndex;
  final List<double> boundingBox; // [left, top, right, bottom]
  final List<List<double>>? landmarks;
  final Float32List embedding; // 512-dim L2 normalized float vector
  final double confidence;
  final DateTime timestamp;

  LocalFaceEmbeddingResult({
    required this.faceIndex,
    required this.boundingBox,
    this.landmarks,
    required this.embedding,
    required this.confidence,
    required this.timestamp,
  });
}

/// Pipeline orchestrating SCRFD 5-point face alignment and ONNX 512D embedding generation.
class LocalFaceEmbeddingPipeline {
  final ModelLoader modelLoader;
  final EmbeddingGenerator embeddingGenerator;

  bool _isReady = false;

  LocalFaceEmbeddingPipeline({
    ModelLoader? modelLoader,
    EmbeddingGenerator? embeddingGenerator,
  })  : modelLoader = modelLoader ?? ModelLoader(),
        embeddingGenerator = embeddingGenerator ?? EmbeddingGenerator();

  bool get isReady => _isReady && modelLoader.isReady;

  Future<bool> initialize() async {
    if (_isReady) return true;
    final ok = await modelLoader.initialize();
    _isReady = ok;
    return ok;
  }

  /// Process camera frame RGB bytes and detected faces to generate 512D embeddings for every face.
  Future<List<LocalFaceEmbeddingResult>> processDetections({
    required Uint8List frameRgbBytes,
    required int frameWidth,
    required int frameHeight,
    required FaceDetectionResult detectionResult,
  }) async {
    if (!isReady) {
      await initialize();
    }

    if (detectionResult.faces.isEmpty) {
      return [];
    }

    final results = <LocalFaceEmbeddingResult>[];
    final Stopwatch sw = Stopwatch()..start();

    for (int i = 0; i < detectionResult.faces.length; i++) {
      final face = detectionResult.faces[i];

      try {
        // Step 1: Extract 5-point SCRFD landmarks (or construct box center landmarks)
        final List<List<double>> landmarks = face.landmarks ??
            [
              [face.boundingBox[0] * frameWidth, face.boundingBox[1] * frameHeight],
              [face.boundingBox[2] * frameWidth, face.boundingBox[1] * frameHeight],
              [(face.boundingBox[0] + face.boundingBox[2]) / 2 * frameWidth, (face.boundingBox[1] + face.boundingBox[3]) / 2 * frameHeight],
              [face.boundingBox[0] * frameWidth, face.boundingBox[3] * frameHeight],
              [face.boundingBox[2] * frameWidth, face.boundingBox[3] * frameHeight],
            ];

        // Step 2: Perform 5-point similarity alignment to 112x112 NCHW FloatTensor [-1.0, 1.0]
        final Float32List alignedTensor = FaceAlignmentService.alignFaceToRgbTensor(
          srcRgbBytes: frameRgbBytes,
          srcWidth: frameWidth,
          srcHeight: frameHeight,
          landmarks: landmarks,
        );

        // Step 3: Run w600k_mbf.onnx inference to produce 512D L2-normalized Float32 embedding
        final Float32List? embedding = await embeddingGenerator.generateFromTensor(alignedTensor);

        if (embedding != null && embedding.length == 512) {
          results.add(LocalFaceEmbeddingResult(
            faceIndex: i,
            boundingBox: face.boundingBox,
            landmarks: landmarks,
            embedding: embedding,
            confidence: face.confidence,
            timestamp: detectionResult.timestamp,
          ));
        }
      } catch (e) {
        debugPrint('⚠️ [LocalFaceEmbeddingPipeline] Error processing face $i: $e');
      }
    }

    sw.stop();
    debugPrint('⚡ [LocalFaceEmbeddingPipeline] Processed ${results.length} faces into 512D embeddings in ${sw.elapsedMilliseconds} ms');

    return results;
  }
}
