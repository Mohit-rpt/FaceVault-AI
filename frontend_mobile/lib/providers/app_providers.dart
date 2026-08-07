// lib/providers/app_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/person_model.dart';
import '../models/recognition_model.dart';
import '../models/timeline_model.dart';
import '../models/settings_model.dart';
import '../services/auth_service.dart';
import '../services/person_service.dart';
import '../services/recognition_service.dart';
import '../services/timeline_service.dart';
import '../services/settings_service.dart';
import '../services/local_storage/hive_embedding_store.dart';
import '../services/sync/sync_repository.dart';
import '../services/sync/sync_manager.dart';
import '../services/local_recognition/model_loader.dart';
import '../services/local_recognition/vector_index_manager.dart';
import '../services/local_recognition/local_recognition_engine_impl.dart';
import '../services/local_recognition/local_ai_test_service.dart';
import '../services/local_recognition/local_face_embedding_pipeline.dart';
import '../services/local_recognition/embedding_parity_validator.dart';

import '../services/camera/camera_service.dart';
import '../services/camera/mobile_face_detector.dart';
import '../services/camera/frame_processor.dart';

// Core Client & Services Providers
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService();
});

final mobileFaceDetectorProvider = Provider<MobileFaceDetector>((ref) {
  return MobileFaceDetector();
});

final frameProcessorProvider = Provider<FrameProcessor>((ref) {
  final detector = ref.watch(mobileFaceDetectorProvider);
  return FrameProcessor(detector: detector);
});

final localFaceEmbeddingPipelineProvider = Provider<LocalFaceEmbeddingPipeline>((ref) {
  final loader = ref.watch(modelLoaderProvider);
  return LocalFaceEmbeddingPipeline(modelLoader: loader);
});

final embeddingParityValidatorProvider = Provider<EmbeddingParityValidator>((ref) {
  final pipeline = ref.watch(localFaceEmbeddingPipelineProvider);
  return EmbeddingParityValidator(pipeline: pipeline);
});

final hiveEmbeddingStoreProvider = Provider<HiveEmbeddingStore>((ref) {
  return HiveEmbeddingStore();
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final localStore = ref.watch(hiveEmbeddingStoreProvider);
  return SyncRepository(apiClient: client, localStore: localStore);
});

final syncManagerProvider = Provider<SyncManager>((ref) {
  final repo = ref.watch(syncRepositoryProvider);
  return SyncManager(repository: repo);
});

final modelLoaderProvider = Provider<ModelLoader>((ref) {
  return ModelLoader();
});

final vectorIndexManagerProvider = Provider<VectorIndexManager>((ref) {
  final store = ref.watch(hiveEmbeddingStoreProvider);
  return VectorIndexManager(localStore: store);
});

final localRecognitionEngineProvider = Provider<LocalRecognitionEngineImpl>((ref) {
  final store = ref.watch(hiveEmbeddingStoreProvider);
  final loader = ref.watch(modelLoaderProvider);
  final index = ref.watch(vectorIndexManagerProvider);
  return LocalRecognitionEngineImpl(
    localStore: store,
    modelLoader: loader,
    vectorIndexManager: index,
  );
});

final localAiTestServiceProvider = Provider<LocalAiTestService>((ref) {
  final store = ref.watch(hiveEmbeddingStoreProvider);
  return LocalAiTestService(localStore: store);
});

final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthService(apiClient: client);
});

final personServiceProvider = Provider<PersonService>((ref) {
  final client = ref.watch(apiClientProvider);
  return PersonService(apiClient: client);
});

final recognitionServiceProvider = Provider<RecognitionService>((ref) {
  final client = ref.watch(apiClientProvider);
  return RecognitionService(apiClient: client);
});

final timelineServiceProvider = Provider<TimelineService>((ref) {
  final client = ref.watch(apiClientProvider);
  return TimelineService(apiClient: client);
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  final client = ref.watch(apiClientProvider);
  return SettingsService(apiClient: client);
});

// Data Providers

// Persons List Provider (Supports Search Query)
final personsListProvider =
    FutureProvider.family<List<PersonModel>, String?>((ref, search) async {
  final service = ref.watch(personServiceProvider);
  return service.getPersons(search: search);
});

// Person Detail Provider
final personDetailProvider =
    FutureProvider.family<PersonModel, dynamic>((ref, personId) async {
  final service = ref.watch(personServiceProvider);
  return service.getPersonById(personId);
});

// Recognition Logs Provider (Graceful fallback on error)
final recognitionLogsProvider =
    FutureProvider.family<List<RecognitionLogModel>, String?>((ref, date) async {
  try {
    final service = ref.watch(recognitionServiceProvider);
    return await service.getRecognitionLogs(date: date);
  } catch (_) {
    return [];
  }
});

// Timeline Provider per Person (Graceful fallback on error)
final personTimelineProvider =
    FutureProvider.family<List<TimelineModel>, dynamic>((ref, personId) async {
  try {
    final service = ref.watch(timelineServiceProvider);
    return await service.getPersonTimeline(personId);
  } catch (_) {
    return [];
  }
});

// Settings Provider (Graceful fallback on error)
final settingsProvider = FutureProvider<List<SettingModel>>((ref) async {
  try {
    final service = ref.watch(settingsServiceProvider);
    return await service.getSettings();
  } catch (_) {
    return [];
  }
});

// Dashboard Real-time Stats Provider (Graceful fallback on connection failure)
final dashboardStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final personService = ref.watch(personServiceProvider);
  final recognitionService = ref.watch(recognitionServiceProvider);

  try {
    final personsFuture = personService.getPersons(limit: 100);
    final logsTodayFuture = recognitionService.getRecognitionLogs(date: 'today');
    final allLogsFuture = recognitionService.getRecognitionLogs(limit: 100);

    final results = await Future.wait([
      personsFuture,
      logsTodayFuture,
      allLogsFuture,
    ]);

    final persons = results[0] as List<PersonModel>;
    final logsToday = results[1] as List<RecognitionLogModel>;
    final allLogs = results[2] as List<RecognitionLogModel>;

    final unknownLogs = allLogs.where((l) => l.personId == 0).toList();

    return {
      'totalPersons': persons.length,
      'todayMatches': logsToday.length,
      'totalLogs': allLogs.length,
      'unknownFaces': unknownLogs.length,
      'activeCameras': 1,
    };
  } catch (_) {
    return {
      'totalPersons': 0,
      'todayMatches': 0,
      'totalLogs': 0,
      'unknownFaces': 0,
      'activeCameras': 0,
    };
  }
});
