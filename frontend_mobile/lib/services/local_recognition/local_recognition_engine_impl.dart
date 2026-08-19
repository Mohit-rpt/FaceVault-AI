// lib/services/local_recognition/local_recognition_engine_impl.dart

import 'package:flutter/foundation.dart';
import '../camera/mobile_face_detector.dart';
import 'local_face_embedding_pipeline.dart';
import 'local_recognition_result.dart';
import 'vector_index_manager.dart';
import 'face_tracker.dart';
import '../camera/frame_processor.dart' show globalUiClock;

class ProcessFrameResult {
  final List<LocalRecognitionResult> results;
  final int recogStartMicro;
  final int recogEndMicro;
  final int maxAlignMicro;
  final int maxEmbedMicro;
  final int totalSearchMicro;
  final int totalConstructMicro;

  ProcessFrameResult({
    required this.results,
    required this.recogStartMicro,
    required this.recogEndMicro,
    required this.maxAlignMicro,
    required this.maxEmbedMicro,
    required this.totalSearchMicro,
    required this.totalConstructMicro,
  });
}

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

  // Fields for telemetry
  int _diagFramesProcessed = 0;
  int _diagSumAlign = 0;
  int _diagSumEmbed = 0;
  int _diagSumSearch = 0;
  int _diagSumConstruct = 0;
  int _diagSumTotal = 0;
  int _diagMaxAlign = 0;
  int _diagMaxEmbed = 0;
  int _diagMaxSearch = 0;
  int _diagMaxConstruct = 0;
  int _diagMaxTotal = 0;
  int _diagStalls100 = 0;
  DateTime _lastDiagTime = DateTime.fromMillisecondsSinceEpoch(0);

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
  Future<ProcessFrameResult> processFrameDetections({
    required Uint8List frameRgbBytes,
    required int frameWidth,
    required int frameHeight,
    required FaceDetectionResult detectionResult,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (detectionResult.faces.isEmpty) {
      final results = faceTracker.updateTracks([]);
      return ProcessFrameResult(
        results: results,
        recogStartMicro: globalUiClock.elapsedMicroseconds,
        recogEndMicro: globalUiClock.elapsedMicroseconds,
        maxAlignMicro: 0,
        maxEmbedMicro: 0,
        totalSearchMicro: 0,
        totalConstructMicro: 0,
      );
    }

    final int recogStartMicro = globalUiClock.elapsedMicroseconds;
    final totalSw = Stopwatch()..start();

    // 1. Generate Embeddings (Includes Alignment and Inference)
    final embeddingResults = await embeddingPipeline.processDetections(
      frameRgbBytes: frameRgbBytes,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      detectionResult: detectionResult,
    );

    final rawResults = <LocalRecognitionResult>[];

    // Track frame maximums for multiple faces
    int frameMaxAlign = 0;
    int frameMaxEmbed = 0;
    int frameTotalSearch = 0;
    int frameTotalConstruct = 0;

    for (final embResult in embeddingResults) {
      if (embResult.alignMicro > frameMaxAlign) frameMaxAlign = embResult.alignMicro;
      if (embResult.embedMicro > frameMaxEmbed) frameMaxEmbed = embResult.embedMicro;

      // 2. Vector Search
      final searchSw = Stopwatch()..start();
      final matches = vectorIndexManager.search(embResult.embedding, topK: 1);
      searchSw.stop();
      frameTotalSearch += searchSw.elapsedMicroseconds;

      // 3. Result Construction
      final constructSw = Stopwatch()..start();
      String? personId;
      String displayName = 'Unknown';
      double similarity = 0.0;
      bool isKnown = false;
      String state = 'unknown';

      if (matches.isNotEmpty) {
        final match = matches.first;
        similarity = match.similarity;
        if (similarity >= similarityThreshold) {
          personId = match.personId.toString();
          displayName = match.personName;
          isKnown = true;
          state = 'recognized';
        }
      }

      rawResults.add(LocalRecognitionResult(
        trackId: embResult.faceIndex, // Will be updated by tracker
        personId: personId,
        displayName: displayName,
        similarity: similarity,
        isKnown: isKnown,
        boundingBox: embResult.boundingBox,
        timestamp: embResult.timestamp,
        state: state,
      ));
      constructSw.stop();
      frameTotalConstruct += constructSw.elapsedMicroseconds;
    }

    totalSw.stop();
    final totalMicro = totalSw.elapsedMicroseconds;

    // Telemetry Update
    if (embeddingResults.isNotEmpty) {
      _diagFramesProcessed++;
      _diagSumAlign += frameMaxAlign;
      _diagSumEmbed += frameMaxEmbed;
      _diagSumSearch += frameTotalSearch;
      _diagSumConstruct += frameTotalConstruct;
      _diagSumTotal += totalMicro;

      if (frameMaxAlign > _diagMaxAlign) _diagMaxAlign = frameMaxAlign;
      if (frameMaxEmbed > _diagMaxEmbed) _diagMaxEmbed = frameMaxEmbed;
      if (frameTotalSearch > _diagMaxSearch) _diagMaxSearch = frameTotalSearch;
      if (frameTotalConstruct > _diagMaxConstruct) _diagMaxConstruct = frameTotalConstruct;
      if (totalMicro > _diagMaxTotal) _diagMaxTotal = totalMicro;

      final totalMs = totalMicro ~/ 1000;
      if (totalMs > 100) {
        _diagStalls100++;
        // Identify the slowest stage
        String stage = 'total';
        int stageMs = totalMs;
        final maxEmbedMs = frameMaxEmbed ~/ 1000;
        final totalSearchMs = frameTotalSearch ~/ 1000;
        final maxAlignMs = frameMaxAlign ~/ 1000;
        
        if (maxEmbedMs > 100) { stage = 'embedding'; stageMs = maxEmbedMs; }
        else if (totalSearchMs > 100) { stage = 'search'; stageMs = totalSearchMs; }
        else if (maxAlignMs > 100) { stage = 'alignment'; stageMs = maxAlignMs; }

        debugPrint('[RECOGNITION_STAGE_STALL] frame_id=unknown stage=$stage stage_ms=$stageMs total_ms=$totalMs');
      }

      final now = DateTime.now();
      if (now.difference(_lastDiagTime).inMilliseconds >= 2000 && _diagFramesProcessed > 0) {
        final avgAlign = (_diagSumAlign / _diagFramesProcessed / 1000.0).toStringAsFixed(1);
        final avgEmbed = (_diagSumEmbed / _diagFramesProcessed / 1000.0).toStringAsFixed(1);
        final avgSearch = (_diagSumSearch / _diagFramesProcessed / 1000.0).toStringAsFixed(1);
        final avgConstruct = (_diagSumConstruct / _diagFramesProcessed / 1000.0).toStringAsFixed(1);
        final avgTotal = (_diagSumTotal / _diagFramesProcessed / 1000.0).toStringAsFixed(1);

        final maxAlignMs = _diagMaxAlign ~/ 1000;
        final maxEmbedMs = _diagMaxEmbed ~/ 1000;
        final maxSearchMs = _diagMaxSearch ~/ 1000;
        final maxConstructMs = _diagMaxConstruct ~/ 1000;
        final maxTotalMs = _diagMaxTotal ~/ 1000;

        debugPrint('[RECOGNITION_STAGE_DIAG] frames=$_diagFramesProcessed avg_align=$avgAlign avg_embed=$avgEmbed avg_search=$avgSearch avg_construct=$avgConstruct avg_total=$avgTotal');
        
        debugPrint('[RECOGNITION_STAGE_SUMMARY] frames=$_diagFramesProcessed '
            'avg_align=$avgAlign avg_embed=$avgEmbed avg_search=$avgSearch avg_construct=$avgConstruct avg_total=$avgTotal '
            'max_align=$maxAlignMs max_embed=$maxEmbedMs max_search=$maxSearchMs max_construct=$maxConstructMs max_total=$maxTotalMs '
            'stalls_100ms=$_diagStalls100 worst_frame_id=unknown');

        _diagFramesProcessed = 0;
        _diagSumAlign = 0;
        _diagSumEmbed = 0;
        _diagSumSearch = 0;
        _diagSumConstruct = 0;
        _diagSumTotal = 0;
        _diagMaxAlign = 0;
        _diagMaxEmbed = 0;
        _diagMaxSearch = 0;
        _diagMaxConstruct = 0;
        _diagMaxTotal = 0;
        _diagStalls100 = 0;
        _lastDiagTime = now;
      }
    }

    final int recogEndMicro = globalUiClock.elapsedMicroseconds;

    return ProcessFrameResult(
      results: faceTracker.updateTracks(rawResults),
      recogStartMicro: recogStartMicro,
      recogEndMicro: recogEndMicro,
      maxAlignMicro: frameMaxAlign,
      maxEmbedMicro: frameMaxEmbed,
      totalSearchMicro: frameTotalSearch,
      totalConstructMicro: frameTotalConstruct,
    );
  }

  /// Helper method for direct vector matching test validation.
  List<VectorMatchResult> recognizeFromEmbedding(Float32List queryVector) {
    return vectorIndexManager.search(queryVector, topK: 1);
  }

  void resetTracker() {
    faceTracker.reset();
  }
}
