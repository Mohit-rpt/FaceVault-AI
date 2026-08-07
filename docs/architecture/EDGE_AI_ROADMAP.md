# FaceVault AI — Edge AI Integration Roadmap

> Prepared during Phase 1 Architecture Refactor

---

## Overview

FaceVault AI will transition from a fully cloud-dependent recognition system
to a hybrid architecture where face detection and recognition can run
**on-device** (Edge AI), with the cloud backend serving as the authoritative
data store and sync coordinator.

---

## Phase 1 — Architecture Preparation (Current)

**Status**: ✅ Complete

### What was done
- Created service interfaces (`SyncService`, `VersionService`, `LocalRecognitionService`, `LocalEmbeddingStore`)
- Added configuration flags (`EDGE_AI_ENABLED`, `edgeAiEnabled`)
- Cleaned dead code and unused imports
- Standardized file naming conventions
- Created architecture documentation

### What was NOT done (intentionally)
- No new runtime dependencies installed
- No existing behavior changed
- No new API routes registered
- No database schema changes

---

## Phase 2 — Edge AI Implementation

### Backend Tasks

1. **Sync API Endpoints**
   - `GET /api/v1/sync/embeddings?since={timestamp}` — Delta embedding export
   - `POST /api/v1/sync/acknowledge` — Device sync confirmation
   - `GET /api/v1/sync/status/{device_id}` — Device sync status

2. **Version API Endpoints**
   - `GET /api/v1/version/model` — Current model version info
   - `GET /api/v1/version/compatibility?client_version={ver}` — Compatibility check

3. **Embedding Export Format**
   - Batch serialization of embedding vectors
   - Delta computation (new/updated/deleted since timestamp)
   - Pagination for large embedding sets

### Flutter Tasks

1. **Install Dependencies**
   - `hive` + `hive_flutter` — Local embedding storage
   - `onnxruntime` — On-device ONNX model inference
   - `workmanager` — Background sync scheduling

2. **Implement `LocalEmbeddingStore`**
   - Hive box for embedding vectors
   - Efficient batch upsert
   - Index by person_id for fast lookup

3. **Implement `RemoteSyncService`**
   - Call backend sync delta endpoint
   - Download and store new embeddings locally
   - Track sync timestamp via SharedPreferences
   - Handle network failures gracefully

4. **Implement `LocalRecognitionService`**
   - Load `buffalo_sc` ONNX model on-device
   - Face detection from camera frames
   - 512-dim embedding generation
   - Cosine similarity matching against local cache

5. **Feature Flag Integration**
   - Toggle in Settings screen
   - `EdgeAiConfig.edgeAiEnabled` controls routing
   - When enabled: recognition uses local service
   - When disabled: recognition uses cloud API (current)

---

## Phase 3 — Production Optimization

1. **Background Sync**
   - Periodic sync via WorkManager
   - Incremental delta sync (not full refresh)
   - Sync only on Wi-Fi option

2. **Offline Capability**
   - Full offline recognition when embeddings are cached
   - Queue recognition logs for upload when online

3. **Model Updates**
   - OTA model distribution
   - Version compatibility checks
   - Graceful fallback to cloud if model mismatch

4. **Telemetry**
   - Edge device performance metrics
   - Recognition accuracy monitoring
   - Sync health dashboard

---

## Dependencies Required (Phase 2)

| Package | Platform | Purpose | Install Phase |
|---|---|---|---|
| `hive` | Flutter | Local key-value storage | Phase 2 |
| `hive_flutter` | Flutter | Hive Flutter adapters | Phase 2 |
| `onnxruntime` | Flutter | On-device ONNX inference | Phase 2 |
| `workmanager` | Flutter | Background task scheduling | Phase 2 |
| `camera` | Flutter | Enhanced camera access | Phase 2 |

---

## Risk Mitigation

| Risk | Mitigation |
|---|---|
| ONNX model too large for mobile | `buffalo_sc` is only 14.6 MB — tested and confirmed |
| Memory pressure on mobile | Single-threaded ONNX config, same as backend |
| Sync conflicts | Server is authoritative; device always syncs FROM server |
| Offline data staleness | Configurable sync interval; forced sync on app foreground |
| Model version mismatch | Version compatibility check before enabling edge recognition |
