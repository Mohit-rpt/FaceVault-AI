// lib/services/sync/sync_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sync_repository.dart';
import 'sync_service.dart';

/// Represents all possible states during synchronization.
enum SyncState {
  idle,
  checking,
  downloading,
  applying,
  completed,
  failed,
  retry,
}

/// Orchestrates smart background and manual synchronization.
///
/// Handles:
/// - Version checks
/// - Automatic decision between Bootstrap vs Delta sync
/// - State notifications
/// - Exponential backoff retries on failure
/// - Offline log queue flushing
class SyncManager implements SyncService {
  final SyncRepository repository;

  SyncState _state = SyncState.idle;
  String? _lastError;
  int _retryCount = 0;
  Timer? _periodicTimer;

  final ValueNotifier<SyncState> stateNotifier = ValueNotifier<SyncState>(SyncState.idle);

  SyncManager({required this.repository});

  SyncState get state => _state;
  String? get lastError => _lastError;

  void _updateState(SyncState newState, [String? error]) {
    _state = newState;
    _lastError = error;
    stateNotifier.value = newState;
    debugPrint('🔄 [SyncManager State] $newState ${error != null ? "- $error" : ""}');
  }

  @override
  bool get isSyncing =>
      _state == SyncState.checking ||
      _state == SyncState.downloading ||
      _state == SyncState.applying;

  @override
  Future<DateTime?> getLastSyncTimestamp() async {
    return repository.localStore.getLastSyncTimestamp();
  }

  @override
  Future<SyncResult> syncEmbeddings() async {
    return checkAndSync(forceBootstrap: true);
  }

  @override
  Future<SyncResult> deltaSyncEmbeddings({required DateTime since}) async {
    return checkAndSync(forceBootstrap: false);
  }

  /// Perform smart synchronization (checks local vs remote version)
  Future<SyncResult> checkAndSync({bool forceBootstrap = false}) async {
    if (isSyncing) {
      return SyncResult(
        addedCount: 0,
        updatedCount: 0,
        deletedCount: 0,
        syncTimestamp: DateTime.now(),
        success: false,
        errorMessage: 'Sync already in progress',
      );
    }

    _updateState(SyncState.checking);

    try {
      // Step 1: Flush pending offline logs first
      await repository.flushOfflineLogs();

      // Step 2: Read local and remote version
      final int localVersion = await repository.localStore.getLocalSyncVersion();
      final remoteVersionMap = await repository.getRemoteVersion();
      final int remoteVersion = remoteVersionMap['embedding_version'] as int? ?? 0;

      debugPrint('📊 [Sync Check] Local Ver: $localVersion, Remote Ver: $remoteVersion');

      // Step 3: Determine Sync Mode
      if (forceBootstrap || localVersion == 0) {
        _updateState(SyncState.downloading);
        _updateState(SyncState.applying);
        final result = await repository.performBootstrapSync();
        if (result.success) {
          _retryCount = 0;
          _updateState(SyncState.completed);
        } else {
          _handleFailure(result.errorMessage ?? 'Bootstrap failed');
        }
        return result;
      } else if (localVersion < remoteVersion) {
        _updateState(SyncState.downloading);
        _updateState(SyncState.applying);
        final result = await repository.performDeltaSync(localVersion);
        if (result.success) {
          _retryCount = 0;
          _updateState(SyncState.completed);
        } else {
          _handleFailure(result.errorMessage ?? 'Delta sync failed');
        }
        return result;
      } else {
        // Up to date
        _retryCount = 0;
        final now = DateTime.now();
        await repository.localStore.saveLastSyncTimestamp(now);
        _updateState(SyncState.completed);
        return SyncResult(
          addedCount: 0,
          updatedCount: 0,
          deletedCount: 0,
          syncTimestamp: now,
          success: true,
        );
      }
    } catch (e) {
      final msg = 'Sync Exception: $e';
      _handleFailure(msg);
      return SyncResult(
        addedCount: 0,
        updatedCount: 0,
        deletedCount: 0,
        syncTimestamp: DateTime.now(),
        success: false,
        errorMessage: msg,
      );
    }
  }

  void _handleFailure(String errorMessage) {
    _updateState(SyncState.failed, errorMessage);
    if (_retryCount < 3) {
      _retryCount++;
      _updateState(SyncState.retry, 'Retry attempt $_retryCount in ${_retryCount * 5}s');
      Timer(Duration(seconds: _retryCount * 5), () {
        checkAndSync();
      });
    }
  }

  /// Start non-aggressive background periodic sync (e.g. every 15 minutes)
  void startPeriodicSync({int intervalMinutes = 15}) {
    stopPeriodicSync();
    _periodicTimer = Timer.periodic(Duration(minutes: intervalMinutes), (_) {
      if (!isSyncing) {
        debugPrint('⏰ [Periodic Sync Triggered]');
        checkAndSync();
      }
    });
  }

  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  void dispose() {
    stopPeriodicSync();
    stateNotifier.dispose();
  }
}
