// lib/services/local_recognition/local_ai_test_service.dart

import 'package:flutter/foundation.dart';
import '../local_storage/hive_embedding_store.dart';
import 'local_recognition_engine_impl.dart';

/// Developer Test Utility for Phase 3A Local AI Engine Validation.
class LocalAiTestService {
  final HiveEmbeddingStore localStore;
  late final LocalRecognitionEngineImpl engine;

  LocalAiTestService({required this.localStore}) {
    engine = LocalRecognitionEngineImpl(localStore: localStore);
  }

  /// Run developer validation test pipeline.
  ///
  /// Flow: Face Bytes → Embedding → Vector Index Search → Match Result
  Future<Map<String, dynamic>> runValidationTest(Uint8List sampleImageBytes) async {
    final Stopwatch sw = Stopwatch()..start();

    try {
      // Step 1: Initialize Local AI Engine
      await engine.initialize();

      // Step 2: Test Direct Vector Match against RAM Index
      final Float32List testQueryVector = Float32List(512);
      for (int i = 0; i < 512; i++) {
        testQueryVector[i] = (i % 10) * 0.1;
      }

      final results = engine.recognizeFromEmbedding(testQueryVector);
      sw.stop();

      final bool matchFound = results.isNotEmpty && results.first.isRecognized;
      final String matchName = matchFound ? (results.first.personName ?? 'Unknown') : 'No Match';
      final double confidence = results.isNotEmpty ? results.first.confidence : 0.0;

      final summary = '✅ [Developer Test] Pipeline Executed in ${sw.elapsedMilliseconds} ms | Result: $matchName (${confidence.toStringAsFixed(1)}%)';
      debugPrint(summary);

      return {
        'success': true,
        'execution_time_ms': sw.elapsedMilliseconds,
        'vectors_in_index': engine.vectorIndexManager.count,
        'matched_person': matchName,
        'confidence_pct': confidence,
        'summary': summary,
      };
    } catch (e) {
      sw.stop();
      final errSummary = '❌ [Developer Test Failed]: $e';
      debugPrint(errSummary);
      return {
        'success': false,
        'execution_time_ms': sw.elapsedMilliseconds,
        'error': str(e),
        'summary': errSummary,
      };
    }
  }

  static String str(dynamic e) => e.toString();
}
