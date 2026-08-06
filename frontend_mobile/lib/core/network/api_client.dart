// lib/core/network/api_client.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'api_constants.dart';
import 'api_exception.dart';

class ApiClient {
  late Dio _dio;

  ApiClient({Dio? dio}) {
    _initDio(dio);
  }

  void _initDio([Dio? customDio]) {
    _dio = customDio ??
        Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    _dio.interceptors.clear();
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
      ),
    );
  }

  /// Immediately update Dio base URL and options upon Settings change
  Future<void> updateBaseUrl(String newUrl) async {
    await ApiConstants.saveBaseUrl(newUrl);
    _dio.options.baseUrl = ApiConstants.baseUrl;
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return _processResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _processResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<dynamic> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _processResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _processResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<dynamic> postMultipart(
    String path, {
    required Map<String, dynamic> data,
    List<dynamic>? files,
    String fileKey = 'image',
  }) async {
    try {
      final formData = FormData.fromMap(data);

      if (files != null && files.isNotEmpty) {
        for (int i = 0; i < files.length; i++) {
          final item = files[i];
          if (item == null) continue;

          if (item is MultipartFile) {
            formData.files.add(MapEntry(fileKey, item));
          } else if (item is XFile) {
            final bytes = await item.readAsBytes();
            final name = item.name.isNotEmpty ? item.name : 'image_$i.jpg';
            formData.files.add(
              MapEntry(
                fileKey,
                MultipartFile.fromBytes(bytes, filename: name),
              ),
            );
          } else if (item is Uint8List) {
            formData.files.add(
              MapEntry(
                fileKey,
                MultipartFile.fromBytes(item, filename: 'image_$i.jpg'),
              ),
            );
          } else if (item is File) {
            if (kIsWeb) {
              final bytes = await item.readAsBytes();
              final fileName = item.path.split('/').last.split('\\').last;
              final name = fileName.isNotEmpty ? fileName : 'image_$i.jpg';
              formData.files.add(
                MapEntry(
                  fileKey,
                  MultipartFile.fromBytes(bytes, filename: name),
                ),
              );
            } else {
              final fileName = item.path.split('/').last.split('\\').last;
              formData.files.add(
                MapEntry(
                  fileKey,
                  await MultipartFile.fromFile(
                    item.path,
                    filename: fileName,
                  ),
                ),
              );
            }
          }
        }
      }

      final response = await _dio.post(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return _processResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  dynamic _processResponse(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic> && data.containsKey('success')) {
      final bool success = data['success'] ?? false;
      if (!success) {
        throw ApiException(
          message: data['message'] ?? 'API Request Failed',
          statusCode: response.statusCode,
          details: data['errors'],
        );
      }
      return data['data'] ?? data;
    }
    return data;
  }

  ApiException _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return NetworkException(
        message: 'Unable to connect to server at ${ApiConstants.baseUrl}. Please check backend status.',
      );
    }

    final response = error.response;
    final statusCode = response?.statusCode;

    String errorMessage = 'An unexpected error occurred';
    dynamic errorDetails;

    if (response?.data != null) {
      if (response!.data is Map<String, dynamic>) {
        errorMessage = response.data['detail'] ??
            response.data['message'] ??
            errorMessage;
        errorDetails = response.data['errors'];
      } else if (response.data is String) {
        errorMessage = response.data;
      }
    }

    switch (statusCode) {
      case 401:
        return UnauthorizedException(message: errorMessage);
      case 404:
        return NotFoundException(message: errorMessage);
      case 500:
        return ServerException(message: errorMessage);
      default:
        return ApiException(
          message: errorMessage,
          statusCode: statusCode,
          details: errorDetails,
        );
    }
  }
}
