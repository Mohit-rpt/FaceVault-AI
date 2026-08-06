// lib/services/api_service.dart

import '../core/network/api_client.dart';
import 'person_service.dart';
import 'recognition_service.dart';
import 'timeline_service.dart';
import 'settings_service.dart';

export 'person_service.dart';
export 'recognition_service.dart';
export 'timeline_service.dart';
export 'settings_service.dart';
export 'auth_service.dart';

class ApiService {
  final ApiClient apiClient;
  late final PersonService personService;
  late final RecognitionService recognitionService;
  late final TimelineService timelineService;
  late final SettingsService settingsService;

  ApiService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient() {
    personService = PersonService(apiClient: this.apiClient);
    recognitionService = RecognitionService(apiClient: this.apiClient);
    timelineService = TimelineService(apiClient: this.apiClient);
    settingsService = SettingsService(apiClient: this.apiClient);
  }
}