// lib/services/local_recognition/vector_index_manager.dart

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../local_storage/hive_embedding_store.dart';
import '../local_storage/local_embedding_store.dart';

/// Single item stored in RAM Vector Index for ultra-fast matching.
class VectorIndexItem {
  final int embeddingId;
  final int personId;
  final String personName;
  final Float32List vector;

  VectorIndexItem({
    required this.embeddingId,
    required this.personId,
    required this.personName,
    required this.vector,
  });
}

/// Search match output from VectorIndexManager.
class VectorMatchResult {
  final int personId;
  final String personName;
  final int embeddingId;
  final double similarity;
  final double confidence;
  final bool isMatch;

  VectorMatchResult({
    required this.personId,
    required this.personName,
    required this.embeddingId,
    required this.similarity,
    required this.confidence,
    required this.isMatch,
  });
}

/// In-Memory Vector Index Manager for ultra-fast local similarity search.
///
/// Performance Target:
/// - Index Lookup Latency: < 20 ms for up to 10,000 vectors
/// - Memory Footprint: ~ 2.0 MB RAM for 1,000 vectors
class VectorIndexManager {
  final HiveEmbeddingStore localStore;
  final List<VectorIndexItem> _index = [];

  bool _isLoaded = false;
  int _lastVersion = -1;

  VectorIndexManager({HiveEmbeddingStore? localStore})
      : localStore = localStore ?? HiveEmbeddingStore();

  bool get isLoaded => _isLoaded;
  int get count => _index.length;
  int get embeddingCount => _index.length;

  /// Execute dot product cosine similarity search returning list of matches.
  List<VectorMatchResult> search(Float32List queryVector, {int topK = 1}) {
    final result = searchNearest(queryVector);
    if (result != null) {
      return [result];
    }
    return [];
  }

  /// Load embeddings from Hive local storage into RAM vector matrix.
  Future<void> initialize() async {
    await refreshFromHive();
  }

  /// Refresh RAM vector matrix from Hive (called after delta sync).
  Future<void> refreshFromHive() async {
    try {
      await localStore.initialize();
      final Stopwatch sw = Stopwatch()..start();
      final List<LocalEmbedding> allEmbeddings = await localStore.getAllEmbeddings();

      _index.clear();
      for (final item in allEmbeddings) {
        if (item.vector.length < 512) continue;

        final Float32List f32Vec = Float32List(512);
        for (int i = 0; i < 512; i++) {
          f32Vec[i] = item.vector[i].toDouble();
        }

        _index.add(VectorIndexItem(
          embeddingId: item.embeddingId,
          personId: item.personId,
          personName: item.personName,
          vector: f32Vec,
        ));
      }

      _lastVersion = await localStore.getLocalSyncVersion();
      _isLoaded = true;
      sw.stop();
      debugPrint('⚡ [VectorIndexManager] Loaded ${_index.length} vectors into RAM index in ${sw.elapsedMilliseconds} ms (Version $_lastVersion)');
    } catch (e) {
      debugPrint('⚠️ [VectorIndexManager] Refresh warning: $e');
    }
  }

  /// Execute dot product cosine similarity search against RAM vector matrix.
  ///
  /// Target: < 20 ms latency
  VectorMatchResult? searchNearest(
    Float32List queryVector, {
    double threshold = 0.45,
  }) {
    if (!_isLoaded || _index.isEmpty) {
      return null;
    }

    final Stopwatch sw = Stopwatch()..start();

    VectorIndexItem? bestItem;
    double maxSimilarity = -1.0;

    for (int i = 0; i < _index.length; i++) {
      final item = _index[i];
      final Float32List target = item.vector;

      // Fast vectorized dot product
      double dot = 0.0;
      for (int j = 0; j < 512; j++) {
        dot += queryVector[j] * target[j];
      }

      if (dot > maxSimilarity) {
        maxSimilarity = dot;
        bestItem = item;
      }
    }

    sw.stop();

    if (bestItem == null) return null;

    final double clampedSim = math.max(0.0, math.min(1.0, maxSimilarity));
    final double confidence = (clampedSim * 100).clamp(0.0, 100.0);
    final bool isMatch = clampedSim >= threshold;

    debugPrint('🔍 [VectorIndexSearch] Match: "${bestItem.personName}" (Sim: ${clampedSim.toStringAsFixed(4)}, Conf: ${confidence.toStringAsFixed(1)}%) in ${sw.elapsedMilliseconds} ms');

    return VectorMatchResult(
      personId: bestItem.personId,
      personName: bestItem.personName,
      embeddingId: bestItem.embeddingId,
      similarity: clampedSim,
      confidence: confidence,
      isMatch: isMatch,
    );
  }

  void clear() {
    _index.clear();
    _isLoaded = false;
  }
}
