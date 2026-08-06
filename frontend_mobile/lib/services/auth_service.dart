// lib/services/auth_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/network/api_client.dart';
import '../core/network/api_constants.dart';

class AuthService {
  final ApiClient apiClient;
  final FlutterSecureStorage secureStorage;

  AuthService({
    required this.apiClient,
    FlutterSecureStorage? secureStorage,
  }) : secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await secureStorage.write(key: ApiConstants.authTokenKey, value: token);
    apiClient.setAuthToken(token);
  }

  Future<String?> getToken() async {
    final token = await secureStorage.read(key: ApiConstants.authTokenKey);
    if (token != null) {
      apiClient.setAuthToken(token);
    }
    return token;
  }

  Future<void> logout() async {
    await secureStorage.delete(key: ApiConstants.authTokenKey);
    apiClient.clearAuthToken();
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
