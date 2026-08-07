# FaceVault AI — RAM Vector Index Specification

> **Version**: 3.0 (Phase 3A Implementation)
> **Component**: `VectorIndexManager`

---

## 1. Overview & Objectives

To achieve target recognition latency **< 20 ms**, the Local AI Engine loads cached 512-dim embedding vectors from Hive into an in-memory RAM matrix (`VectorIndexManager`) rather than reading disk storage on every inference call.

---

## 2. In-Memory Data Structure

```dart
class VectorIndexItem {
  final int embeddingId;
  final int personId;
  final String personName;
  final Float32List vector; // 512-dim Float32List
}
```

---

## 3. Cosine Similarity Algorithm

The RAM search engine computes the dot product between the query vector $Q$ and every stored vector $E_k$:

$$\text{Similarity}(Q, E_k) = \sum_{j=1}^{512} Q[j] \cdot E_k[j]$$

Since both $Q$ and $E_k$ are pre-normalized to unit L2 length ($\|Q\|_2 = 1, \|E_k\|_2 = 1$), the dot product equals the exact Cosine Similarity.

---

## 4. Benchmark Performance & Scalability Targets

| Number of Stored Persons / Vectors | RAM Footprint | Search Latency (Single Thread CPU) |
|---|---|---|
| 100 Vectors | ~ 0.2 MB | < 0.8 ms |
| 1,000 Vectors | ~ 2.0 MB | < 4.2 ms |
| 10,000 Vectors | ~ 20.0 MB | < 18.5 ms |

---

## 5. Lifecycle & Sync Invalidation

1. **Startup**: `VectorIndexManager.initialize()` loads active embeddings into RAM.
2. **Delta Sync Invalidation**: When `SyncManager` downloads delta updates or deletes soft-deleted records, it calls `VectorIndexManager.refreshFromHive()` to refresh the RAM index dynamically.
