// lib/services/local_recognition/local_recognition_engine_impl.dart

import 'package:flutter/foundation.dart';
import '../camera/mobile_face_detector.dart';
import 'local_face_embedding_pipeline.dart';
import 'local_recognition_result.dart';
import 'vector_index_manager.dart';
import 'face_tracker.dart';

/// Implementation of Local Live Face Recognition Engine.
///
/// Integrates SCRFD face detection, 5-point alignment, ONNX embedding generation,
/// RAM vector search, temporal recognition stability, and multi-face tracking.
class LocalRecognitionEngineImpl {
  final LocalFaceEmbeddingPipeline embeddingPipeline;
  final VectorIndexManager vectorIndexManager;
  final FaceTracker faceTracker;

  /// Configurable Similarity Threshold (Default = 0.45)
  double similarityThreshold;
  bool _isInitialized = false;

  LocalRecognitionEngineImpl({
    LocalFaceEmbeddingPipeline? embeddingPipeline,
    VectorIndexManager? vectorIndexManager,
    FaceTracker? faceTracker,
    this.similarityThreshold = 0.45,
  })  : embeddingPipeline = embeddingPipeline ?? LocalFaceEmbeddingPipeline(),
        vectorIndexManager = vectorIndexManager ?? VectorIndexManager(),
        faceTracker = faceTracker ?? FaceTracker();

  bool get isInitialized => _isInitialized;

  /// Initialize pipeline and RAM vector index.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      await embeddingPipeline.initialize();
      await vectorIndexManager.initialize();
      _isInitialized = true;
      debugPrint('⚡ [LocalRecognitionEngineImpl] Initialized with threshold $similarityThreshold and ${vectorIndexManager.embeddingCount} vectors in RAM index');
      return true;
    } catch (e) {
      debugPrint('⚠️ [LocalRecognitionEngineImpl] Initialization error: $e');
      return false;
    }
  }

  /// Process live camera frame bytes and SCRFD detection results.
  Future<List<LocalRecognitionResult>> processFrameDetections({
    required Uint8List frameRgbBytes,
    required int frameWidth,
    required int frameHeight,
    required FaceDetectionResult detectionResult,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (detectionResult.faces.isEmpty) {
      return faceTracker.updateTracks([]);
    }

    final rawResults = <LocalRecognitionResult>[];

    // TEMPORARY DETECTION-ONLY MODE FOR DEBUGGING
    // Disable embedding and vector search to prevent performance collapse
    // while we debug the 135-faces SCRFD issue.
    for (int i = 0; i < detectionResult.faces.length; i++) {
      final face = detectionResult.faces[i];
      rawResults.add(LocalRecognitionResult(
        trackId: i,
        personId: null,
        displayName: 'DEBUG',
        similarity: face.confidence, // Borrow similarity field to show raw SCRFD confidence
        isKnown: false,
        boundingBox: face.boundingBox,
        timestamp: detectionResult.timestamp,
        state: 'raw',
      ));
    }

    // 3. Apply Temporal Recognition Stability & Multi-Object Tracking
    final trackedResults = faceTracker.updateTracks(rawResults);
    return trackedResults;
  }

  /// Helper method for direct vector matching test validation.
  List<VectorMatchResult> recognizeFromEmbedding(Float32List queryVector) {
    return vectorIndexManager.search(queryVector, topK: 1);
  }

  void resetTracker() {
    faceTracker.reset();
  }
}
