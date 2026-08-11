// lib/services/local_storage/hive_embedding_store.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'local_embedding_store.dart';

/// Concrete Hive implementation of [LocalEmbeddingStore].
///
/// Manages high-performance local key-value boxes:
/// - `facevault_persons`: Stores Person metadata & details
/// - `facevault_embeddings`: Stores 512-dim embedding vectors & metadata
/// - `facevault_images`: Stores face image metadata
/// - `facevault_sync_meta`: Stores local sync version, last sync time, and offline logs queue
class HiveEmbeddingStore implements LocalEmbeddingStore {
  static final HiveEmbeddingStore _instance = HiveEmbeddingStore._internal();
  factory HiveEmbeddingStore() => _instance;
  HiveEmbeddingStore._internal();

  static const String boxPersons = 'facevault_persons';
  static const String boxEmbeddings = 'facevault_embeddings';
  static const String boxImages = 'facevault_images';
  static const String boxSyncMeta = 'facevault_sync_meta';

  static const String keyLocalVersion = 'local_embedding_version';
  static const String keyLastSyncTime = 'last_sync_timestamp';
  static const String keyOfflineLogs = 'pending_offline_logs';

  Box? _personsBox;
  Box? _embeddingsBox;
  Box? _imagesBox;
  Box? _syncMetaBox;

  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();

    _personsBox = await Hive.openBox(boxPersons);
    _embeddingsBox = await Hive.openBox(boxEmbeddings);
    _imagesBox = await Hive.openBox(boxImages);
    _syncMetaBox = await Hive.openBox(boxSyncMeta);

    _isInitialized = true;
    debugPrint('✅ HiveEmbeddingStore initialized successfully');
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('HiveEmbeddingStore is not initialized. Call initialize() first.');
    }
  }

  // ==================== Embedding Methods ====================

  @override
  Future<void> upsertEmbedding(LocalEmbedding embedding) async {
    _ensureInitialized();
    final data = {
      'embedding_id': embedding.embeddingId,
      'person_id': embedding.personId,
      'person_name': embedding.personName,
      'vector': embedding.vector.toList(),
      'synced_at': embedding.syncedAt.toIso8601String(),
    };
    await _embeddingsBox?.put(embedding.embeddingId, data);
  }

  @override
  Future<void> upsertEmbeddings(List<LocalEmbedding> embeddings) async {
    _ensureInitialized();
    final Map<dynamic, dynamic> entries = {};
    for (final emb in embeddings) {
      entries[emb.embeddingId] = {
        'embedding_id': emb.embeddingId,
        'person_id': emb.personId,
        'person_name': emb.personName,
        'vector': emb.vector.toList(),
        'synced_at': emb.syncedAt.toIso8601String(),
      };
    }
    await _embeddingsBox?.putAll(entries);
  }

  /// Store raw JSON map embedding payload directly from sync API
  Future<void> saveRawEmbeddingMap(Map<String, dynamic> map) async {
    _ensureInitialized();
    final int embeddingId = map['embedding_id'] as int;
    final int personId = map['person_id'] as int;

    // Decode Base64 binary vector if present into Float64List
    Float64List? vec;
    final String? b64 = map['embedding_vector_b64'] as String?;
    if (b64 != null && b64.isNotEmpty) {
      final bytes = base64Decode(b64);
      final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
      final floatCount = bytes.length ~/ 8;
      vec = Float64List(floatCount);
      for (int i = 0; i < floatCount; i++) {
        vec[i] = byteData.getFloat64(i * 8, Endian.little);
      }
    }

    final entry = {
      'embedding_id': embeddingId,
      'person_id': personId,
      'model_name': map['model_name'] ?? 'buffalo_sc',
      'embedding_dimension': map['embedding_dimension'] ?? 512,
      'quality_score': map['quality_score'],
      'embedding_version': map['embedding_version'] ?? 1,
      'is_deleted': map['is_deleted'] ?? false,
      'vector': vec?.toList(),
      'synced_at': DateTime.now().toIso8601String(),
    };

    await _embeddingsBox?.put(embeddingId, entry);
  }

  @override
  Future<List<LocalEmbedding>> getAllEmbeddings() async {
    _ensureInitialized();
    final results = <LocalEmbedding>[];
    if (_embeddingsBox == null) return results;

    for (final key in _embeddingsBox!.keys) {
      final raw = _embeddingsBox!.get(key);
      if (raw is Map) {
        final isDeleted = raw['is_deleted'] == true;
        if (isDeleted) continue;

        final List<dynamic>? vecList = raw['vector'] as List<dynamic>?;
        if (vecList == null || vecList.isEmpty) continue;

        final floatVec = Float64List.fromList(vecList.map((e) => (e as num).toDouble()).toList());

        results.add(LocalEmbedding(
          embeddingId: raw['embedding_id'] as int,
          personId: raw['person_id'] as int,
          personName: raw['person_name'] as String? ?? 'Person ${raw['person_id']}',
          vector: floatVec,
          syncedAt: DateTime.tryParse(raw['synced_at'] as String? ?? '') ?? DateTime.now(),
        ));
      }
    }
    return results;
  }

  @override
  Future<List<LocalEmbedding>> getEmbeddingsByPersonId(int personId) async {
    final all = await getAllEmbeddings();
    return all.where((e) => e.personId == personId).toList();
  }

  @override
  Future<void> deleteEmbedding(int embeddingId) async {
    _ensureInitialized();
    await _embeddingsBox?.delete(embeddingId);
  }

  @override
  Future<void> deleteEmbeddingsByPersonId(int personId) async {
    _ensureInitialized();
    if (_embeddingsBox == null) return;
    final keysToDelete = <dynamic>[];
    for (final key in _embeddingsBox!.keys) {
      final raw = _embeddingsBox!.get(key);
      if (raw is Map && raw['person_id'] == personId) {
        keysToDelete.add(key);
      }
    }
    await _embeddingsBox?.deleteAll(keysToDelete);
  }

  @override
  Future<int> getEmbeddingCount() async {
    _ensureInitialized();
    final all = await getAllEmbeddings();
    return all.length;
  }

  // ==================== Person Methods ====================

  Future<void> savePersonMap(Map<String, dynamic> personMap) async {
    _ensureInitialized();
    final int personId = personMap['person_id'] as int;
    await _personsBox?.put(personId, personMap);
  }

  Future<Map<String, dynamic>?> getPersonMap(int personId) async {
    _ensureInitialized();
    final raw = _personsBox?.get(personId);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllPersonMaps() async {
    _ensureInitialized();
    final results = <Map<String, dynamic>>[];
    if (_personsBox == null) return results;

    for (final key in _personsBox!.keys) {
      final raw = _personsBox!.get(key);
      if (raw is Map) {
        results.add(Map<String, dynamic>.from(raw));
      }
    }
    return results;
  }

  // ==================== Metadata & Sync Version Methods ====================

  Future<int> getLocalSyncVersion() async {
    _ensureInitialized();
    return _syncMetaBox?.get(keyLocalVersion, defaultValue: 0) as int? ?? 0;
  }

  Future<void> saveLocalSyncVersion(int version) async {
    _ensureInitialized();
    await _syncMetaBox?.put(keyLocalVersion, version);
  }

  Future<DateTime?> getLastSyncTimestamp() async {
    _ensureInitialized();
    final str = _syncMetaBox?.get(keyLastSyncTime) as String?;
    if (str != null) return DateTime.tryParse(str);
    return null;
  }

  Future<void> saveLastSyncTimestamp(DateTime timestamp) async {
    _ensureInitialized();
    await _syncMetaBox?.put(keyLastSyncTime, timestamp.toIso8601String());
  }

  // ==================== Offline Log Queue Methods ====================

  Future<void> enqueueOfflineLog(Map<String, dynamic> logEntry) async {
    _ensureInitialized();
    final logs = await getPendingOfflineLogs();
    logs.add(logEntry);
    await _syncMetaBox?.put(keyOfflineLogs, logs);
  }

  Future<List<Map<String, dynamic>>> getPendingOfflineLogs() async {
    _ensureInitialized();
    final raw = _syncMetaBox?.get(keyOfflineLogs);
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> clearOfflineLogs() async {
    _ensureInitialized();
    await _syncMetaBox?.delete(keyOfflineLogs);
  }

  @override
  Future<void> clearAll() async {
    _ensureInitialized();
    await _personsBox?.clear();
    await _embeddingsBox?.clear();
    await _imagesBox?.clear();
    await _syncMetaBox?.clear();
  }

  @override
  Future<void> dispose() async {
    await _personsBox?.close();
    await _embeddingsBox?.close();
    await _imagesBox?.close();
    await _syncMetaBox?.close();
    _isInitialized = false;
  }
}
