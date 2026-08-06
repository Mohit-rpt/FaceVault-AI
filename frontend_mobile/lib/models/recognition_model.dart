// lib/models/recognition_model.dart

class RecognizedFaceModel {
  final int personId;
  final String personName;
  final double confidence;
  final double similarity;
  final List<double> boundingBox;

  RecognizedFaceModel({
    required this.personId,
    required this.personName,
    required this.confidence,
    required this.similarity,
    required this.boundingBox,
  });

  factory RecognizedFaceModel.fromJson(Map<String, dynamic> json) {
    return RecognizedFaceModel(
      personId: json['person_id'] ?? 0,
      personName: json['person_name'] ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0.0,
      boundingBox: (json['bounding_box'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
    );
  }
}

class UnknownFaceModel {
  final double confidence;
  final List<double> boundingBox;

  UnknownFaceModel({
    required this.confidence,
    required this.boundingBox,
  });

  factory UnknownFaceModel.fromJson(Map<String, dynamic> json) {
    return UnknownFaceModel(
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      boundingBox: (json['bounding_box'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
    );
  }
}

class RecognitionResponseModel {
  final bool success;
  final int processingTimeMs;
  final int facesDetected;
  final List<RecognizedFaceModel> recognizedFaces;
  final List<UnknownFaceModel> unknownFaces;

  RecognitionResponseModel({
    required this.success,
    required this.processingTimeMs,
    required this.facesDetected,
    required this.recognizedFaces,
    required this.unknownFaces,
  });

  factory RecognitionResponseModel.fromJson(Map<String, dynamic> json) {
    return RecognitionResponseModel(
      success: json['success'] ?? true,
      processingTimeMs: json['processing_time_ms'] ?? 0,
      facesDetected: json['faces_detected'] ?? 0,
      recognizedFaces: (json['recognized_faces'] as List<dynamic>?)
              ?.map((e) => RecognizedFaceModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      unknownFaces: (json['unknown_faces'] as List<dynamic>?)
              ?.map((e) => UnknownFaceModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class RecognitionLogModel {
  final int logId;
  final int personId;
  final String? personName;
  final double confidenceScore;
  final String? cameraSource;
  final int? recognitionTimeMs;
  final String? recognizedAt;

  RecognitionLogModel({
    required this.logId,
    required this.personId,
    this.personName,
    required this.confidenceScore,
    this.cameraSource,
    this.recognitionTimeMs,
    this.recognizedAt,
  });

  factory RecognitionLogModel.fromJson(Map<String, dynamic> json) {
    String? name;
    if (json['person'] is Map<String, dynamic>) {
      name = json['person']['name'];
    } else {
      name = json['person_name'];
    }

    return RecognitionLogModel(
      logId: json['log_id'] ?? json['id'] ?? 0,
      personId: json['person_id'] ?? 0,
      personName: name,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      cameraSource: json['camera_source'] as String?,
      recognitionTimeMs: json['recognition_time_ms'] as int?,
      recognizedAt: json['recognized_at'] as String?,
    );
  }
}
