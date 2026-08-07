/// Local Recognition Service Interface — Phase 1 Architecture Placeholder.
///
/// Defines the contract for on-device face recognition using ONNX Runtime.
///
/// Phase 2 will provide a concrete implementation that:
/// - Loads buffalo_sc ONNX model on-device
/// - Performs face detection from camera frames
/// - Generates 512-dim embeddings locally
/// - Matches against locally cached embeddings
///
/// No ONNX Runtime dependency is installed in Phase 1.
library;

import 'dart:typed_data';

/// Represents a face detected and recognized locally on-device.
class LocalRecognitionResult {
  final int? personId;
  final String? personName;
  final double confidence;
  final double similarity;
  final bool isRecognized;
  final List<double> boundingBox;
  final Float64List? embedding;

  const LocalRecognitionResult({
    this.personId,
    this.personName,
    required this.confidence,
    required this.similarity,
    required this.isRecognized,
    required this.boundingBox,
    this.embedding,
  });
}

/// Abstract interface for on-device face recognition.
abstract class LocalRecognitionService {
  /// Initialize the ONNX model and prepare for inference.
  Future<void> initialize();

  /// Check if the model is loaded and ready.
  bool get isReady;

  /// Recognize faces in a raw image (camera frame bytes).
  ///
  /// Returns a list of recognition results, one per detected face.
  Future<List<LocalRecognitionResult>> recognizeFromBytes(Uint8List imageBytes);

  /// Generate embedding vector from a face image without matching.
  Future<Float64List?> generateEmbedding(Uint8List faceImageBytes);

  /// Release model resources.
  Future<void> dispose();
}
