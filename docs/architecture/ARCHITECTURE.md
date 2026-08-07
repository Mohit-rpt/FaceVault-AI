# FaceVault AI — System Architecture

> **Version**: 2.0 (Phase 1 — Architecture Preparation)
> **Last Updated**: 2026-08-07

---

## 1. High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                        FaceVault AI System                          │
├────────────────────────┬─────────────────────┬───────────────────────┤
│   Flutter Mobile App   │  React Dashboard    │  FastAPI Backend      │
│   (iOS/Android/Web)    │  (Web)              │  (Python)             │
├────────────────────────┴─────────────────────┴───────────────────────┤
│                     REST API (JSON over HTTPS)                       │
├──────────────────────────────────────────────────────────────────────┤
│                     PostgreSQL (Neon Cloud)                           │
└──────────────────────────────────────────────────────────────────────┘
```

### Current Flow (v1)
```
Camera/Image → Backend API → InsightFace (buffalo_sc) → Embedding → PostgreSQL → Recognition
```

### Future Flow (v2 — Phase 2+)
```
Camera/Image → On-Device ONNX (buffalo_sc) → Local Embedding Cache → Local Match
                                            ↕ Background Sync ↕
                                     Backend API → PostgreSQL
```

---

## 2. Backend Architecture

### 2.1 Technology Stack

| Component | Technology |
|---|---|
| Framework | FastAPI (Python 3.11) |
| Database | PostgreSQL (Neon Cloud) |
| ORM | SQLAlchemy 2.x |
| Migrations | Alembic |
| AI Model | InsightFace `buffalo_sc` (ONNX) |
| Runtime | ONNX Runtime (CPU) |
| Deployment | Render (512MB RAM) |

### 2.2 Module Structure

```
backend/app/
├── main.py                    # FastAPI app, lifespan, CORS, routers
├── api/                       # API route handlers
│   ├── persons.py             # Person CRUD, face registration, search
│   ├── recognition.py         # Face recognition, logs
│   ├── settings.py            # System settings CRUD
│   ├── camera.py              # Camera stream management
│   ├── sync.py                # [Phase 2] Embedding sync endpoints
│   └── version.py             # [Phase 2] Model version endpoints
├── core/                      # Configuration & utilities
│   ├── config.py              # Settings (DB, thresholds, feature flags)
│   ├── exceptions.py          # HTTP exception hierarchy
│   ├── response.py            # Standardized API response format
│   └── utils.py               # File URL formatting
├── crud/                      # Database CRUD operations
│   └── person.py              # All DB read/write operations
├── database/                  # Database connection
│   └── database.py            # Engine, SessionLocal, Base
├── models/                    # SQLAlchemy ORM models
│   └── models.py              # Person, FaceEmbedding, FaceImage, etc.
├── schemas/                   # Pydantic request/response schemas
│   └── schemas.py             # All API schemas
└── services/                  # Business logic & AI services
    ├── face_detector.py       # InsightFace wrapper (singleton)
    ├── face_detector_instance.py  # Thread-safe singleton accessor
    ├── embedding_service.py   # Embedding normalization pipeline
    ├── embedding_normalizer.py    # L2 normalization, serialization
    ├── recognition_service.py # Main recognition orchestrator
    ├── similarity.py          # Cosine similarity engine
    ├── live_recognition.py    # Real-time video recognition
    ├── camera_manager.py      # Camera stream management
    ├── image_validator.py     # Image format validation
    ├── image_quality.py       # Image quality assessment
    ├── face_alignment.py      # Face alignment (5-point landmarks)
    ├── interfaces.py          # Protocol definitions (VectorSearchBackend)
    ├── exceptions.py          # Service-level exceptions
    ├── sync_service.py        # [Phase 2] Embedding sync logic
    └── version_service.py     # [Phase 2] Model version management
```

### 2.3 AI Model Lifecycle

```
Application Startup (lifespan)
        │
        ▼
get_face_detector()  ← Thread-safe singleton
        │
        ▼
FaceAnalysis(name="buffalo_sc", providers=["CPUExecutionProvider"])
        │
        ▼
prepare(ctx_id=-1, det_size=(320, 320))
        │
        ▼
✅ Singleton stored in memory (13 MB)
        │
        ▼
All API requests reuse this single instance
```

### 2.4 Database Schema

```
persons
├── person_id (PK)
├── name, nickname, relationship
├── created_at, updated_at
│
├── person_details (1:1)
│   └── phone, email, birthday, gender, company, designation, etc.
│
├── face_embeddings (1:N)
│   └── embedding_vector (binary), model_name, quality_score, etc.
│
├── face_images (1:N)
│   └── image_path, capture_source, quality_score, image_hash
│
├── recognition_logs (1:N)
│   └── confidence_score, camera_source, recognition_time_ms
│
├── interaction_timeline (1:N)
│   └── title, description, location, tags, interaction_date
│
└── custom_fields (1:N)
    └── field_name, field_value

settings
└── setting_key (unique), setting_value

face_sessions
└── session_name, camera_source, started_at, ended_at
```

### 2.5 Recognition Pipeline

```
Image Upload
    │
    ▼
ImageValidator.validate_or_raise()    ← Format, dimensions, channels
    │
    ▼
FaceDetector.detect()                 ← InsightFace detection + embedding
    │
    ▼
ImageQualityAssessor.check()          ← Blur, brightness, contrast
    │
    ▼
EmbeddingService.get_embedding()      ← L2 normalization
    │
    ▼
CosineSimilarityEngine.find_best_match()  ← np.dot() against all stored vectors
    │
    ├── Match found (score > threshold) → RecognizedFace
    └── No match → UnknownFace (saved to disk)
```

---

## 3. Flutter Mobile Architecture

### 3.1 Technology Stack

| Component | Technology |
|---|---|
| Framework | Flutter 3.x (Dart) |
| State Management | Riverpod 2.x |
| HTTP Client | Dio 5.x |
| Persistence | SharedPreferences |
| Auth Storage | flutter_secure_storage |
| Typography | Google Fonts (Rajdhani, Orbitron) |

### 3.2 Module Structure

```
frontend_mobile/lib/
├── main.dart                  # App entry point, ProviderScope
├── core/
│   ├── network/
│   │   ├── api_client.dart    # Dio wrapper (GET, POST, PUT, DELETE, Multipart)
│   │   ├── api_constants.dart # Base URL, endpoint routes
│   │   └── api_exception.dart # Typed exception hierarchy
│   ├── theme/
│   │   └── app_theme.dart     # Cyberpunk dark theme
│   └── edge_ai/               # [Phase 2] On-device AI config
│       └── edge_ai_config.dart
├── models/
│   ├── person_model.dart      # PersonModel, PersonDetailModel, etc.
│   ├── recognition_model.dart # RecognitionResponseModel, logs
│   ├── settings_model.dart    # SettingModel
│   └── timeline_model.dart    # TimelineModel
├── services/
│   ├── person_service.dart    # Person CRUD + face registration
│   ├── recognition_service.dart  # Recognition API
│   ├── settings_service.dart  # Settings CRUD
│   ├── timeline_service.dart  # Timeline CRUD
│   ├── auth_service.dart      # Token management
│   ├── api_service.dart       # Service aggregator
│   ├── sync/                  # [Phase 2] Embedding sync
│   │   ├── sync_service.dart
│   │   └── remote_sync_service.dart
│   ├── local_storage/         # [Phase 2] On-device embedding cache
│   │   └── local_embedding_store.dart
│   └── local_recognition/     # [Phase 2] On-device recognition
│       └── local_recognition_service.dart
├── providers/
│   └── app_providers.dart     # All Riverpod providers
├── navigation/
│   └── app_shell.dart         # Bottom nav + PageView (8 tabs)
├── features/
│   ├── dashboard/             # Stats grid, activity feed
│   ├── persons/               # Person list, details, editor
│   ├── registration/          # 3-step wizard (Capture → Form → Review)
│   ├── recognition/           # Live face scanner
│   ├── camera/                # Camera stream management
│   ├── analytics/             # Charts and metrics
│   ├── timeline/              # Interaction history
│   ├── logs/                  # Recognition audit logs
│   ├── unknown/               # Unidentified face logs
│   └── settings/              # Backend URL config
├── shared/
│   ├── widgets/               # GlassCard, CyberButton, CyberTextField, etc.
│   └── components/            # DashboardStatsCard, etc.
└── utils/
    └── responsive.dart        # Breakpoint helpers
```

### 3.3 Data Flow

```
UI Screen (ConsumerWidget)
    │
    ▼
Riverpod Provider (FutureProvider.family)
    │
    ▼
Service Layer (PersonService, RecognitionService, etc.)
    │
    ▼
ApiClient (Dio)
    │
    ▼
FastAPI Backend (/api/v1/...)
```

---

## 4. React Dashboard Architecture

### 4.1 Technology Stack

| Component | Technology |
|---|---|
| Framework | React + TypeScript |
| Build Tool | Vite |
| HTTP Client | Axios |
| Styling | Tailwind CSS |
| Animations | Framer Motion |

### 4.2 Page Structure

| Page | Route | Description |
|---|---|---|
| Dashboard | `/` | System overview, stats, activity feed |
| Persons | `/persons` | Person directory with search |
| Person Profile | `/persons/:id` | Full profile, timeline, images |
| Register Face | `/register` | Face registration form |
| Live Recognition | `/recognition` | Real-time camera recognition |
| Recognition Logs | `/logs` | Audit log history |
| Timeline | `/timeline` | System-wide event timeline |
| Analytics | `/analytics` | Usage charts and metrics |
| Unknown Faces | `/unknown` | Unidentified face gallery |
| Camera Settings | `/camera` | Camera stream configuration |
| Settings | `/settings` | System configuration |

---

## 5. Configuration Flags

### Backend (`backend/app/core/config.py`)

| Flag | Default | Purpose |
|---|---|---|
| `EDGE_AI_ENABLED` | `False` | Master switch for Edge AI sync endpoints |
| `SIMILARITY_THRESHOLD` | `0.45` | Cosine similarity match threshold |
| `QUALITY_THRESHOLD` | `0.20` | Minimum face image quality score |

### Flutter (`frontend_mobile/lib/core/edge_ai/edge_ai_config.dart`)

| Flag | Default | Purpose |
|---|---|---|
| `edgeAiEnabled` | `false` | Master switch for on-device recognition |
| `similarityThreshold` | `0.45` | Local match threshold |
| `maxLocalEmbeddings` | `10000` | Max cached embeddings |
| `syncIntervalMinutes` | `15` | Background sync frequency |

---

## 6. Phase Roadmap

### Phase 1 (Current) — Architecture Preparation
- ✅ Clean codebase, remove dead code
- ✅ Create service interfaces for sync, versioning, local recognition
- ✅ Add configuration flags (disabled by default)
- ✅ Zero breaking changes

### Phase 2 — Edge AI Implementation
- [ ] Install ONNX Runtime Flutter plugin
- [ ] Install Hive for local embedding storage
- [ ] Implement `LocalEmbeddingStore` (Hive)
- [ ] Implement `RemoteSyncService` (backend API ↔ device)
- [ ] Implement backend sync endpoints
- [ ] Implement `LocalRecognitionService` (on-device inference)
- [ ] Feature flag toggle in Settings screen

### Phase 3 — Production Optimization
- [ ] Background sync with WorkManager
- [ ] Incremental model updates
- [ ] Offline recognition capability
- [ ] Sync conflict resolution
- [ ] Edge device telemetry
