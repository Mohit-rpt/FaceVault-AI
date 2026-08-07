/// Local Embedding Store Interface — Phase 1 Architecture Placeholder.
///
/// Defines the contract for storing face embeddings on-device.
///
/// Phase 2 will provide concrete implementations using:
/// - Hive (lightweight, fast key-value store)
/// - OR SQLite via sqflite (relational queries)
///
/// No dependencies are installed in Phase 1.
library;

import 'dart:typed_data';

/// Represents a locally cached face embedding.
class LocalEmbedding {
  final int embeddingId;
  final int personId;
  final String personName;
  final Float64List vector;
  final DateTime syncedAt;

  const LocalEmbedding({
    required this.embeddingId,
    required this.personId,
    required this.personName,
    required this.vector,
    required this.syncedAt,
  });
}

/// Abstract interface for local embedding storage.
abstract class LocalEmbeddingStore {
  /// Initialize the local store (open database/box).
  Future<void> initialize();

  /// Store or update an embedding locally.
  Future<void> upsertEmbedding(LocalEmbedding embedding);

  /// Store or update multiple embeddings in batch.
  Future<void> upsertEmbeddings(List<LocalEmbedding> embeddings);

  /// Retrieve all active embeddings for recognition.
  Future<List<LocalEmbedding>> getAllEmbeddings();

  /// Retrieve embeddings for a specific person.
  Future<List<LocalEmbedding>> getEmbeddingsByPersonId(int personId);

  /// Remove an embedding by its ID.
  Future<void> deleteEmbedding(int embeddingId);

  /// Remove all embeddings for a person.
  Future<void> deleteEmbeddingsByPersonId(int personId);

  /// Get total count of locally stored embeddings.
  Future<int> getEmbeddingCount();

  /// Clear all local embeddings.
  Future<void> clearAll();

  /// Close the local store and release resources.
  Future<void> dispose();
}
