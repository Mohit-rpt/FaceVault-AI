// lib/services/timeline_service.dart

import '../core/network/api_client.dart';
import '../core/network/api_constants.dart';
import '../models/timeline_model.dart';

class TimelineService {
  final ApiClient apiClient;

  TimelineService({required this.apiClient});

  Future<List<TimelineModel>> getPersonTimeline(
    dynamic personId, {
    int skip = 0,
    int limit = 100,
  }) async {
    final response = await apiClient.get(
      ApiConstants.personTimeline(personId),
      queryParameters: {'skip': skip, 'limit': limit},
    );

    if (response is List<dynamic>) {
      return response
          .map((e) => TimelineModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<TimelineModel> createTimeline(
    dynamic personId,
    TimelineCreateReq req,
  ) async {
    final response = await apiClient.post(
      ApiConstants.personTimeline(personId),
      data: req.toJson(),
    );
    return TimelineModel.fromJson(response as Map<String, dynamic>);
  }
}
