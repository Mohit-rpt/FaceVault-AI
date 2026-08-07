/// Remote Sync Service — Phase 1 Architecture Placeholder.
///
/// Will implement [SyncService] to synchronize embeddings
/// between the FaceVault backend API and local device storage.
///
/// Phase 2 implementation will:
/// - Call backend sync API endpoints
/// - Download new/updated embeddings
/// - Remove deleted embeddings from local store
/// - Track sync state via SharedPreferences
library;

import 'sync_service.dart';

/// Placeholder implementation for backend ↔ device embedding sync.
///
/// Not functional until Phase 2. All methods throw [UnimplementedError].
class RemoteSyncService implements SyncService {
  @override
  Future<SyncResult> syncEmbeddings() {
    throw UnimplementedError('RemoteSyncService will be implemented in Phase 2');
  }

  @override
  Future<SyncResult> deltaSyncEmbeddings({required DateTime since}) {
    throw UnimplementedError('RemoteSyncService will be implemented in Phase 2');
  }

  @override
  Future<DateTime?> getLastSyncTimestamp() {
    throw UnimplementedError('RemoteSyncService will be implemented in Phase 2');
  }

  @override
  bool get isSyncing => false;
}
