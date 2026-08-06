// lib/models/settings_model.dart

class SettingModel {
  final int settingId;
  final String key;
  final String? value;
  final String? updatedAt;

  SettingModel({
    required this.settingId,
    required this.key,
    this.value,
    this.updatedAt,
  });

  factory SettingModel.fromJson(Map<String, dynamic> json) {
    return SettingModel(
      settingId: json['setting_id'] ?? 0,
      key: json['setting_key'] ?? json['key'] ?? '',
      value: json['setting_value'] ?? json['value']?.toString(),
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'setting_key': key,
      'setting_value': value,
    };
  }
}
