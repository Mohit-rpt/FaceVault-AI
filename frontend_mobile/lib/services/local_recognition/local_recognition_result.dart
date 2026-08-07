// lib/services/local_recognition/local_recognition_result.dart

/// Data model representing local face recognition result for a single face.
class LocalRecognitionResult {
  final int trackId;
  final String? personId;
  final String displayName;
  final double similarity;
  final bool isKnown;
  final List<double> boundingBox; // [left, top, right, bottom]
  final DateTime timestamp;
  final String state; // newTrack, active, confirmed, lost, removed

  LocalRecognitionResult({
    required this.trackId,
    this.personId,
    required this.displayName,
    required this.similarity,
    required this.isKnown,
    required this.boundingBox,
    required this.timestamp,
    required this.state,
  });

  @override
  String toString() {
    return 'Track #$trackId: ${isKnown ? displayName : "Unknown"} (${(similarity * 100).toStringAsFixed(1)}%) State: $state';
  }
}
