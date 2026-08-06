// lib/services/person_service.dart

import '../core/network/api_client.dart';
import '../core/network/api_constants.dart';
import '../models/person_model.dart';

class PersonService {
  final ApiClient apiClient;

  PersonService({required this.apiClient});

  Future<List<PersonModel>> getPersons({
    int skip = 0,
    int limit = 50,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'skip': skip,
      'limit': limit,
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final response = await apiClient.get(
      ApiConstants.persons,
      queryParameters: queryParams,
    );

    List<dynamic> items = [];
    if (response is Map<String, dynamic> && response.containsKey('items')) {
      items = response['items'] as List<dynamic>;
    } else if (response is List<dynamic>) {
      items = response;
    }

    return items
        .map((e) => PersonModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PersonModel> getPersonById(dynamic id) async {
    final response = await apiClient.get(ApiConstants.personById(id));
    return PersonModel.fromJson(response as Map<String, dynamic>);
  }

  Future<PersonModel> createPerson(PersonCreateReq req) async {
    final response = await apiClient.post(
      ApiConstants.persons,
      data: req.toJson(),
    );
    return PersonModel.fromJson(response as Map<String, dynamic>);
  }

  Future<PersonModel> updatePerson(
    dynamic id,
    Map<String, dynamic> updateData,
  ) async {
    final response = await apiClient.put(
      ApiConstants.personById(id),
      data: updateData,
    );
    return PersonModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deletePerson(dynamic id) async {
    await apiClient.delete(ApiConstants.personById(id));
  }

  Future<Map<String, dynamic>> registerFace(
    dynamic personId,
    List<dynamic> imageFiles,
  ) async {
    final response = await apiClient.postMultipart(
      ApiConstants.registerFace(personId),
      data: {},
      files: imageFiles,
      fileKey: 'files',
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {'success': true, 'message': 'Face registered successfully'};
  }

  /// Face-Based Search: Upload an image file to find matching Person profile
  Future<Map<String, dynamic>> searchByFace(dynamic imageFile) async {
    final response = await apiClient.postMultipart(
      '/persons/search-by-face',
      data: {},
      files: [imageFile],
      fileKey: 'file',
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {'matched': false, 'message': 'Invalid response from search server'};
  }

  /// Add a custom field to a person profile
  Future<CustomFieldModel> addCustomField(
    dynamic personId,
    String fieldName,
    String? fieldValue,
  ) async {
    final response = await apiClient.post(
      '/persons/$personId/custom-fields',
      data: {
        'field_name': fieldName,
        if (fieldValue != null) 'field_value': fieldValue,
      },
    );
    return CustomFieldModel.fromJson(response as Map<String, dynamic>);
  }

  /// Edit an existing custom field
  Future<CustomFieldModel> updateCustomField(
    dynamic personId,
    dynamic fieldId,
    String fieldName,
    String? fieldValue,
  ) async {
    final response = await apiClient.put(
      '/persons/$personId/custom-fields/$fieldId',
      data: {
        'field_name': fieldName,
        if (fieldValue != null) 'field_value': fieldValue,
      },
    );
    return CustomFieldModel.fromJson(response as Map<String, dynamic>);
  }

  /// Delete a custom field from a person profile
  Future<void> deleteCustomField(dynamic personId, dynamic fieldId) async {
    await apiClient.delete('/persons/$personId/custom-fields/$fieldId');
  }

  /// Delete a specific face image from a person profile
  Future<void> deleteFaceImage(dynamic personId, dynamic imageId) async {
    await apiClient.delete('/persons/$personId/images/$imageId');
  }
}
