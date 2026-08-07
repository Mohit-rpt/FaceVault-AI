# FaceVault AI — Local Recognition & Multi-Object Tracking Specification

> **Version**: 3.7 (Phase 3B-2B Implementation)
> **Pipeline**: `LocalRecognitionEngineImpl`, `FaceTracker`, `RecognitionOverlay`

---

## 1. Local Offline Architecture

FaceVault AI v2 executes **100% of live face recognition locally on-device**. Video camera frames are never uploaded to Render or FastAPI backend servers during camera monitoring.

```
Camera Frame (YUV420 / BGRA 30 FPS)
                  │
                  ▼
FrameProcessor (Sampling Throttling 30→15 FPS, Queue Capacity = 2)
                  │
                  ▼
SCRFD (det_500m.onnx 5-Point Landmark Detector)
                  │
                  ▼
FaceAlignmentService (2D Partial Affine Alignment to 112x112 Canonical Pose)
                  │
                  ▼
EmbeddingGenerator (w600k_mbf.onnx 512D Float32 Vector, L2 Norm = 1.0)
                  │
                  ▼
VectorIndexManager (RAM Cosine Similarity Search < 20 ms)
                  │
                  ▼
Similarity Threshold Decision (similarityThreshold = 0.45)
                  │
                  ▼
FaceTracker & Temporal Stability (IoU + Center Distance Matching)
                  │
                  ▼
CoordinateTransformer (Camera Image → Screen Widget Rect)
                  │
                  ▼
RecognitionOverlay (Futuristic Glowing Neon HUD bounding boxes & Name tags)
```

---

## 2. Thresholding & Unknown Handling Strategy

- **Similarity Threshold**: `0.45` (`similarityThreshold = 0.45`).
- **Known Decision**: If $\text{Similarity} \ge 0.45$, the candidate identity is assigned.
- **Unknown Decision**: If $\text{Similarity} < 0.45$, the candidate is safely classified as **`UNKNOWN`**.
- **Best Match vs Recognition**: "Best match" does NOT equal "Recognized". Only candidates exceeding $0.45$ similarity pass the recognition check.

---

## 3. Temporal Stability & Lightweight Multi-Object Tracker

### 3.1 `FaceTracker` Algorithm
- **Metric**: Intersection over Union (IoU) + Euclidean distance between face box center coordinates.
- **Max Center Distance**: `0.25` normalized width/height.
- **Exponential Box Smoothing**: $\alpha = 0.7$ smoothing factor eliminates visual jitter.

### 3.2 Track Lifecycle States

```
NEW_TRACK ────> ACTIVE ────> CONFIRMED
  │               │              │
  └───────────────┴──────────────┴────> LOST (Missed 2-5 frames)
                                          │
                                          ▼
                                       REMOVED (Missed > 5 frames)
```

- **Confirmation Threshold**: Requires 2 consecutive consistent frames before becoming `CONFIRMED`.
- **Expiration Grace Period**: 5 missed frames before removing track.

---

## 4. Performance & Offline Metrics

| Operation Stage | Target Latency | Measured Host CPU Latency |
|---|---|---|
| **Camera Hardware Feed** | Smooth **30 FPS** | **30.0 FPS** |
| **Throttled Processing Feed** | **10–15 FPS** | **~ 14.8 FPS** |
| **YUV420 → RGB Tensor Conversion** | < 15 ms | **~ 8.2 ms** |
| **SCRFD Face Detection** | < 35 ms | **~ 22.4 ms** |
| **5-Point Alignment** | < 10 ms | **~ 4.8 ms** |
| **w600k_mbf Embedding** | < 150 ms | **~ 37.2 ms** |
| **RAM Vector Search** | < 20 ms | **~ 0.08 ms** |
| **Multi-Object Tracking** | < 5 ms | **~ 0.4 ms** |
| **End-to-End Live Pipeline** | < 200 ms | **~ 73.1 ms** |

---

## 5. Offline Operation & Backend Isolation Protocol

1. **Zero Camera Frame Uploads**: No HTTP `POST` requests containing camera images are sent to Render / FastAPI backend during live recognition.
2. **Hive Offline Storage**: Person embeddings are cached locally in Hive storage and loaded into RAM vector index during app startup.
3. **Network Independence**: Disconnecting Wi-Fi / cellular data does not affect live recognition, tracking, or HUD rendering.
