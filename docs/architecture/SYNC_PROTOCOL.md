# FaceVault AI — Smart Synchronization Protocol Specification

> **Version**: 2.0 (Phase 2 Implementation)
> **Status**: Active

---

## 1. Overview & Objectives

The Smart Synchronization Protocol manages high-efficiency, offline-first data sync between the **FastAPI Cloud Backend** and **Flutter Mobile / Edge Clients**.

### Key Principles
1. **Delta Synchronization**: Transmits **only** embeddings and person profiles modified after the client's current version index (`embedding_version`).
2. **Version Sequence Tracking**: Every embedding mutation increments the server's global version sequence.
3. **Bandwidth Optimization**: Avoids re-downloading unchanged records.
4. **Offline Resilience**: Mobile clients queue recognition logs locally when offline and flush them to the server upon network availability.
5. **Non-Blocking Operation**: All sync routines execute asynchronously in background isolates.

---

## 2. API Specifications

### 2.1 Get Server Sync Version
- **Endpoint**: `GET /api/v1/sync/version`
- **Response**:
```json
{
  "success": true,
  "data": {
    "embedding_version": 14,
    "last_updated": "2026-08-07T09:26:00.000000"
  },
  "message": "Sync version retrieved"
}
```

---

### 2.2 Get Delta Sync Payload
- **Endpoint**: `GET /api/v1/sync/delta?version={client_version}`
- **Query Parameter**: `version` (integer, required) - The client's current local `embedding_version`.

#### Response (Client is Up-to-Date):
```json
{
  "success": true,
  "data": {
    "status": "up_to_date",
    "version": 14,
    "last_updated": "2026-08-07T09:26:00.000000",
    "changed_embeddings": [],
    "deleted_embedding_ids": [],
    "changed_persons": []
  },
  "message": "Delta sync data retrieved"
}
```

#### Response (Delta Available):
```json
{
  "success": true,
  "data": {
    "status": "delta_available",
    "version": 15,
    "last_updated": "2026-08-07T09:28:15.000000",
    "changed_embeddings": [
      {
        "embedding_id": 42,
        "person_id": 7,
        "model_name": "buffalo_sc",
        "embedding_dimension": 512,
        "quality_score": 0.94,
        "embedding_version": 15,
        "is_deleted": false,
        "created_at": "2026-08-07T09:28:15",
        "updated_at": "2026-08-07T09:28:15",
        "embedding_vector_b64": "..."
      }
    ],
    "deleted_embedding_ids": [12, 19],
    "changed_persons": [
      {
        "person_id": 7,
        "name": "Sarah Connor",
        "nickname": "Sarah",
        "relationship": "Verified",
        "is_deleted": false,
        "details": {
          "phone": "+1234567890",
          "email": "sarah@example.com",
          "company": "Cyberdyne Systems"
        }
      }
    ]
  },
  "message": "Delta sync data retrieved"
}
```

---

### 2.3 Initial Installation Bootstrap Sync
- **Endpoint**: `GET /api/v1/sync/bootstrap`
- **Description**: Returns full snapshot of all active persons, details, images metadata, and 512-dim embedding vectors for fresh app installations.

---

### 2.4 Upload Offline Recognition Logs
- **Endpoint**: `POST /api/v1/sync/logs`
- **Request Body**:
```json
[
  {
    "person_id": 7,
    "confidence_score": 98.5,
    "camera_source": "Mobile_Camera",
    "recognition_time_ms": 42,
    "recognized_at": "2026-08-07T09:25:00.000000"
  }
]
```
- **Response**:
```json
{
  "success": true,
  "data": {
    "success": true,
    "inserted": 1,
    "errors": []
  },
  "message": "Successfully synced 1 offline logs"
}
```

---

## 3. Sequence Diagram

```
Mobile App (Flutter)                       FastAPI Server                           Neon PostgreSQL
      │                                          │                                         │
      ├────── 1. GET /sync/version ─────────────>│                                         │
      │                                          ├────── Query max(embedding_version) ────>│
      │<───── 2. { embedding_version: 15 } ──────│<───── Max Version: 15 ──────────────────┤
      │                                          │                                         │
      │── Compare Local (12) vs Remote (15) ─────│                                         │
      │                                          │                                         │
      ├────── 3. GET /sync/delta?version=12 ────>│                                         │
      │                                          ├────── Query embeddings > version 12 ───>│
      │<───── 4. { delta_available, ... } ───────│<───── Changed & Deleted Records ────────┤
      │                                          │                                         │
      ├── 5. Apply changes to Hive Local Storage │                                         │
      └── 6. Update local version index to 15    │                                         │
```

---

## 4. Sync State Machine

The `SyncManager` transitions through 7 distinct operational states:

```
    ┌──────┐
    │ Idle │
    └──┬───┘
       │ Trigger (App launch / Periodic / Pull-to-refresh)
       ▼
 ┌──────────┐      Up to date      ┌───────────┐
 │ Checking │─────────────────────>│ Completed │
 └─────┬────┘                      └───────────┘
       │ Changes available
       ▼
 ┌────────────┐     ┌──────────┐     ┌───────────┐
 │Downloading │────>│ Applying │────>│ Completed │
 └────────────┘     └──────────┘     └───────────┘
       │                 │
       └────────┬────────┘
                │ Error encountered
                ▼
           ┌────────┐     Attempt < 3     ┌───────┐
           │ Failed │───────────────────> │ Retry │ (Exponential backoff)
           └────────┘                     └───┬───┘
                ▲                             │
                └─────────────────────────────┘
```
