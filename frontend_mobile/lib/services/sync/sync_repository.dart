// lib/services/sync/sync_repository.dart

import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../local_storage/hive_embedding_store.dart';
import 'sync_service.dart';

/// Clean repository layer connecting [ApiClient], [HiveEmbeddingStore], and [SyncManager].
class SyncRepository {
  final ApiClient apiClient;
  final HiveEmbeddingStore localStore;

  SyncRepository({
    required this.apiClient,
    required this.localStore,
  });

  /// Fetch remote max embedding version and timestamp from FastAPI backend.
  Future<Map<String, dynamic>> getRemoteVersion() async {
    final response = await apiClient.get('/sync/version');
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {'embedding_version': 0, 'last_updated': DateTime.now().toIso8601String()};
  }

  /// Perform Bootstrap Sync: Download full active snapshot and write to local Hive storage.
  Future<SyncResult> performBootstrapSync() async {
    final response = await apiClient.get('/sync/bootstrap');
    if (response is! Map<String, dynamic>) {
      return SyncResult(
        addedCount: 0,
        updatedCount: 0,
        deletedCount: 0,
        syncTimestamp: DateTime.now(),
        success: false,
        errorMessage: 'Invalid bootstrap response payload',
      );
    }

    final int remoteVer = response['version'] as int? ?? 1;
    final List<dynamic> persons = response['persons'] as List<dynamic>? ?? [];
    final List<dynamic> embeddings = response['embeddings'] as List<dynamic>? ?? [];

    // Clear local storage for clean bootstrap
    await localStore.clearAll();

    // Write Persons to Hive
    for (final p in persons) {
      if (p is Map<String, dynamic>) {
        await localStore.savePersonMap(p);
      }
    }

    // Write Embeddings to Hive
    for (final e in embeddings) {
      if (e is Map<String, dynamic>) {
        await localStore.saveRawEmbeddingMap(e);
      }
    }

    final now = DateTime.now();
    await localStore.saveLocalSyncVersion(remoteVer);
    await localStore.saveLastSyncTimestamp(now);

    debugPrint('✅ Bootstrap Sync applied: ${persons.length} persons, ${embeddings.length} embeddings (Ver: $remoteVer)');

    return SyncResult(
      addedCount: embeddings.length,
      updatedCount: 0,
      deletedCount: 0,
      syncTimestamp: now,
      success: true,
    );
  }

  /// Perform Delta Sync: Download only modifications made after [clientVersion].
  Future<SyncResult> performDeltaSync(int clientVersion) async {
    final response = await apiClient.get(
      '/sync/delta',
      queryParameters: {'version': clientVersion},
    );

    if (response is! Map<String, dynamic>) {
      return SyncResult(
        addedCount: 0,
        updatedCount: 0,
        deletedCount: 0,
        syncTimestamp: DateTime.now(),
        success: false,
        errorMessage: 'Invalid delta response payload',
      );
    }

    final String status = response['status'] as String? ?? 'up_to_date';
    final int newVer = response['version'] as int? ?? clientVersion;
    final now = DateTime.now();

    if (status == 'up_to_date') {
      await localStore.saveLastSyncTimestamp(now);
      return SyncResult(
        addedCount: 0,
        updatedCount: 0,
        deletedCount: 0,
        syncTimestamp: now,
        success: true,
      );
    }

    final List<dynamic> changedEmbeddings = response['changed_embeddings'] as List<dynamic>? ?? [];
    final List<dynamic> deletedEmbeddingIds = response['deleted_embedding_ids'] as List<dynamic>? ?? [];
    final List<dynamic> changedPersons = response['changed_persons'] as List<dynamic>? ?? [];

    // Apply changed persons
    for (final p in changedPersons) {
      if (p is Map<String, dynamic>) {
        await localStore.savePersonMap(p);
      }
    }

    // Apply changed embeddings
    for (final e in changedEmbeddings) {
      if (e is Map<String, dynamic>) {
        await localStore.saveRawEmbeddingMap(e);
      }
    }

    // Delete soft-deleted embeddings
    for (final id in deletedEmbeddingIds) {
      if (id is int) {
        await localStore.deleteEmbedding(id);
      }
    }

    await localStore.saveLocalSyncVersion(newVer);
    await localStore.saveLastSyncTimestamp(now);

    debugPrint('✅ Delta Sync applied: +${changedEmbeddings.length} modified, -${deletedEmbeddingIds.length} deleted (Ver: $newVer)');

    return SyncResult(
      addedCount: changedEmbeddings.length,
      updatedCount: 0,
      deletedCount: deletedEmbeddingIds.length,
      syncTimestamp: now,
      success: true,
    );
  }

  /// Upload offline recognition logs queued locally on mobile device.
  Future<bool> flushOfflineLogs() async {
    final pendingLogs = await localStore.getPendingOfflineLogs();
    if (pendingLogs.isEmpty) return true;

    try {
      final response = await apiClient.post('/sync/logs', data: pendingLogs);
      if (response is Map<String, dynamic> && response['inserted'] != null) {
        await localStore.clearOfflineLogs();
        debugPrint('✅ Flushed ${pendingLogs.length} offline logs to server');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Offline log flush deferred: $e');
    }
    return false;
  }
}
