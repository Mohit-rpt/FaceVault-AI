// lib/core/network/api_constants.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  static const String keyBaseUrl = 'saved_api_base_url';

  static String get defaultBaseUrl {
  return 'https://facevault-backend-85sn.onrender.com/api/v1';
}

  static String baseUrl = const String.fromEnvironment(
    'BASE_URL',
    defaultValue: '',
  );

  /// Sanitize IP based on platform
  static String sanitizeUrl(String rawUrl) {
  String trimmed = rawUrl.trim();

  if (trimmed.isEmpty) {
    return defaultBaseUrl;
  }

  return trimmed;
}

  /// Load persisted base URL from SharedPreferences on app startup.
  static Future<String> initBaseUrl() async {
    try {
      if (baseUrl.isEmpty) {
        baseUrl = defaultBaseUrl;
      }
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(keyBaseUrl);
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        baseUrl = sanitizeUrl(savedUrl);
      }
    } catch (_) {
      baseUrl = defaultBaseUrl;
    }
    return baseUrl;
  }

  /// Save new Base URL to SharedPreferences.
  static Future<void> saveBaseUrl(String newUrl) async {
    baseUrl = sanitizeUrl(newUrl);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyBaseUrl, baseUrl);
    } catch (_) {}
  }

  // Endpoint routes
  static const String persons = '/persons';
  static String personById(dynamic id) => '/persons/$id';
  static String registerFace(dynamic personId) => '/persons/$personId/register-face';
  static String personTimeline(dynamic personId) => '/persons/$personId/timeline';

  static const String recognition = '/recognition';
  static const String recognitionLogs = '/recognition/logs';

  static const String settings = '/settings';
  static String settingByKey(String key) => '/settings/$key';

  // Storage keys for authentication
  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
}
