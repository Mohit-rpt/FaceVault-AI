// lib/services/settings_service.dart

import '../core/network/api_client.dart';
import '../core/network/api_constants.dart';
import '../models/settings_model.dart';

class SettingsService {
  final ApiClient apiClient;

  SettingsService({required this.apiClient});

  Future<List<SettingModel>> getSettings() async {
    final response = await apiClient.get(ApiConstants.settings);
    if (response is List<dynamic>) {
      return response
          .map((e) => SettingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<SettingModel> updateSetting(String key, String value) async {
    final response = await apiClient.put(
      ApiConstants.settingByKey(key),
      data: {'setting_key': key, 'setting_value': value},
    );
    return SettingModel.fromJson(response as Map<String, dynamic>);
  }
}
