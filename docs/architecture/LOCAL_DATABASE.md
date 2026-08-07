# FaceVault AI — Local Database Architecture & Storage Specification

> **Version**: 2.0 (Phase 2 Implementation)
> **Engine**: Hive Key-Value Store (`hive_flutter`)

---

## 1. Overview

The local database layer provides offline-first data persistence for the Flutter application using **Hive**, a lightweight, zero-dependency, ultra-fast key-value database written in pure Dart.

---

## 2. Hive Boxes Architecture

```
frontend_mobile/
└── Hive Storage Root
    ├── facevault_persons       (Person metadata & bio details)
    ├── facevault_embeddings    (512-dim embedding Float64List vectors & quality scores)
    ├── facevault_images        (Face image local file paths & cloud URLs)
    └── facevault_sync_meta     (Local sync version, timestamp, pending offline logs queue)
```

---

## 3. Schema & Data Contracts

### 3.1 `facevault_persons` Box
- **Key**: `person_id` (integer)
- **Value**: JSON Map
```json
{
  "person_id": 7,
  "name": "Sarah Connor",
  "nickname": "Sarah",
  "relationship": "Verified",
  "is_deleted": false,
  "created_at": "2026-08-07T09:28:15",
  "details": {
    "phone": "+1234567890",
    "email": "sarah@example.com",
    "company": "Cyberdyne Systems"
  }
}
```

### 3.2 `facevault_embeddings` Box
- **Key**: `embedding_id` (integer)
- **Value**: JSON Map with Float64List vector representation
```json
{
  "embedding_id": 42,
  "person_id": 7,
  "model_name": "buffalo_sc",
  "embedding_dimension": 512,
  "quality_score": 0.94,
  "embedding_version": 15,
  "is_deleted": false,
  "vector": [0.0142, -0.0521, ..., 0.0891],
  "synced_at": "2026-08-07T09:30:00.000000"
}
```

### 3.3 `facevault_sync_meta` Box
- **Keys**:
  - `local_embedding_version`: `15` (integer)
  - `last_sync_timestamp`: `"2026-08-07T09:30:00.000000"` (ISO string)
  - `pending_offline_logs`: `[ {...}, {...} ]` (List of queued offline recognition maps)

---

## 4. Performance & Memory Benchmarks

| Metric | Target / Measured Value |
|---|---|
| **Box Open Time** | < 15 ms |
| **Lookup Latency (by ID)** | < 1 ms |
| **Vector Deserialization (512-dim Float64)** | ~ 0.02 ms per embedding |
| **Storage Size (1,000 Persons + Embeddings)** | ~ 4.2 MB |
| **Storage Size (10,000 Embeddings)** | ~ 42.0 MB |

---

## 5. Storage Lifecycle & Cleanup

1. **Incremental Updates**: Delta sync updates single records in `facevault_embeddings` by `embedding_id` without rewriting the box.
2. **Soft Deletions**: Soft-deleted records on the backend trigger `HiveEmbeddingStore.deleteEmbedding(id)`.
3. **App Cache Reset**: In `HiveEmbeddingStore.clearAll()`, all boxes are cleared cleanly on manual user logout or full reset.
