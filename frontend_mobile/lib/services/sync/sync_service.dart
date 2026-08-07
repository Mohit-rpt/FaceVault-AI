/// Sync Service Interface — Phase 1 Architecture Placeholder.
///
/// Defines the contract for synchronizing face embeddings between
/// the cloud backend and local on-device storage.
///
/// Phase 2 will provide [RemoteSyncService] implementation.
library;

/// Represents the result of a sync operation.
class SyncResult {
  final int addedCount;
  final int updatedCount;
  final int deletedCount;
  final DateTime syncTimestamp;
  final bool success;
  final String? errorMessage;

  const SyncResult({
    required this.addedCount,
    required this.updatedCount,
    required this.deletedCount,
    required this.syncTimestamp,
    required this.success,
    this.errorMessage,
  });
}

/// Abstract sync service defining the synchronization contract.
abstract class SyncService {
  /// Perform a full synchronization of embeddings.
  Future<SyncResult> syncEmbeddings();

  /// Perform a delta sync (only changes since last sync).
  Future<SyncResult> deltaSyncEmbeddings({required DateTime since});

  /// Get the timestamp of the last successful sync.
  Future<DateTime?> getLastSyncTimestamp();

  /// Check if a sync is currently in progress.
  bool get isSyncing;
}
