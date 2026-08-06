// lib/services/recognition_service.dart

import '../core/network/api_client.dart';
import '../core/network/api_constants.dart';
import '../models/recognition_model.dart';

class RecognitionService {
  final ApiClient apiClient;

  RecognitionService({required this.apiClient});

  Future<RecognitionResponseModel> recognizeFaces(
    dynamic imageFile, {
    String? cameraSource,
  }) async {
    final response = await apiClient.postMultipart(
      ApiConstants.recognition,
      data: {
        if (cameraSource != null) 'camera_source': cameraSource,
      },
      files: [imageFile],
      fileKey: 'image',
    );

    return RecognitionResponseModel.fromJson(
      response as Map<String, dynamic>,
    );
  }

  Future<List<RecognitionLogModel>> getRecognitionLogs({
    int skip = 0,
    int limit = 50,
    String? date,
    int? personId,
  }) async {
    final queryParams = <String, dynamic>{
      'skip': skip,
      'limit': limit,
    };
    if (date != null) queryParams['date'] = date;
    if (personId != null) queryParams['person_id'] = personId;

    final response = await apiClient.get(
      ApiConstants.recognitionLogs,
      queryParameters: queryParams,
    );

    List<dynamic> items = [];
    if (response is Map<String, dynamic> && response.containsKey('items')) {
      items = response['items'] as List<dynamic>;
    } else if (response is List<dynamic>) {
      items = response;
    }

    return items
        .map((e) => RecognitionLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
