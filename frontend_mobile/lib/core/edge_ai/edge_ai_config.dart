/// Edge AI Configuration — Phase 1 Architecture Placeholder.
///
/// Provides configuration flags and settings for future on-device
/// face recognition using ONNX Runtime.
///
/// Phase 1: All flags default to disabled.
/// Phase 2: Will be connected to Settings screen and local preferences.
library;

class EdgeAiConfig {
  /// Master feature flag for Edge AI functionality.
  /// When false, all recognition uses cloud API (current behavior).
  /// When true, recognition will use on-device ONNX Runtime (Phase 2).
  static const bool edgeAiEnabled = false;

  /// Local ONNX model file name (Phase 2).
  static const String modelName = 'buffalo_sc';

  /// Embedding dimension produced by the model.
  static const int embeddingDimension = 512;

  /// Similarity threshold for local recognition matches.
  static const double similarityThreshold = 0.45;

  /// Maximum number of embeddings to cache locally.
  static const int maxLocalEmbeddings = 10000;

  /// Background sync interval in minutes.
  static const int syncIntervalMinutes = 15;
}
