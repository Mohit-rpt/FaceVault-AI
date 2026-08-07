# FaceVault AI — Camera & Frame Processing Pipeline Specification

> **Version**: 3.5 (Phase 3B-1 Implementation)
> **Engine**: Mobile Camera + Real-Time Frame Processing Pipeline

---

## 1. Overview & Architecture

Phase 3B-1 establishes the real-time mobile camera hardware capture, frame throttling, bounded queueing, YUV420 $\rightarrow$ RGB planar tensor conversion, and face detection pipeline without executing face recognition or sending camera frames to backend cloud APIs.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CAMERA PROCESSING PIPELINE                         │
│                                                                             │
│  ┌───────────────────────┐         ┌─────────────────────────────────────┐  │
│  │     CameraService     │────────>│           FrameProcessor            │  │
│  │(Hardware Controller & │ 30 FPS  │ (Sampling Throttling 30→15 FPS,     │  │
│  │   Image Stream)       │         │  Metrics & Queue Management)        │  │
│  └───────────────────────┘         └──────────────────┬──────────────────┘  │
│                                                       │                     │
│                                                       ▼                     │
│  ┌───────────────────────┐         ┌─────────────────────────────────────┐  │
│  │  MobileFaceDetector   │<────────│           ImageConverter            │  │
│  │(det_500m.onnx SCRFD   │ Bounding│   (YUV420_888 / BGRA8888 →          │  │
│  │ Bounding Box Detector)│  Boxes  │    Normalized NCHW RGB FloatTensor)│  │
│  └───────────┬───────────┘         └─────────────────────────────────────┘  │
│              │                                                              │
│              ▼                                                              │
│  ┌───────────────────────┐                                                  │
│  │ CoordinateTransformer │ (Prepares normalized [left, top, right, bottom]  │
│  │ (Image → Screen Space)│  rectangles for Phase 3B-2 HUD rendering)        │
│  └───────────────────────┘                                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Component Specifications

### 2.1 `CameraService`
- Encapsulates `CameraController` lifecycle and hardware streams.
- Defaults to `ImageFormatGroup.yuv420` on Android and `ImageFormatGroup.bgra8888` on iOS.
- Handles camera switching (Front vs Back lens) and orientation detection.

### 2.2 `FrameQueue`
- **Capacity**: Bounded at `maxCapacity = 2`.
- **Strategy**: Always prefers newest frames. When full, drops oldest frame to prevent memory accumulation.
- **Locking**: Uses `isProcessingLock` flag to guarantee single-frame execution.

### 2.3 `FrameProcessor` & Throttling
- **Camera Feed**: ~ 30 FPS.
- **Target Processing Feed**: 10–15 FPS (`targetProcessingIntervalMs = 66ms`).
- **Metrics Tracked**: `cameraFps`, `processingFps`, `framesReceived`, `framesProcessed`, `framesDropped`, `averageProcessingTimeMs`, `queueSize`, `detectedFaceCount`.

### 2.4 `ImageConverter`
- Converts YUV420_888 3-plane camera buffers (Y, U, V with rowStrides & pixelStrides) into normalized NCHW planar RGB float tensor `[1, 3, 112, 112]`.
- Normalization formula: $\frac{\text{pixel} - 127.5}{127.5}$.

### 2.5 `MobileFaceDetector`
- Uses `onnxruntime` session with `assets/models/det_500m.onnx` (InsightFace SCRFD detector, 2.5 MB).
- Returns `FaceDetectionResult` containing list of `FaceDetectionBox` items with bounding boxes `[left, top, right, bottom]` and confidence scores.

### 2.6 `CoordinateTransformer`
- Transforms normalized coordinates $(0.0 - 1.0)$ into screen widget pixel coordinates.
- Accounts for front-camera horizontal mirroring (`1.0 - right`).

---

## 3. Performance Expectations

| Metric | Target Value |
|---|---|
| Camera Preview | Smooth **30 FPS** |
| Frame Processing | **10–15 FPS** (Throttled) |
| Frame Conversion Latency | < 12 ms |
| Face Detection Latency | < 35 ms |
| Total Pipeline Frame Latency | < 50 ms |
| Frame Queue Size | Max **2** items |

---

## 4. Phase 3B-2 Integration Points

In **Phase 3B-2**, the output of `MobileFaceDetector` will be connected to:
1. Face Cropping & Alignment (`FaceAlignment`)
2. `EmbeddingGenerator` (`w600k_mbf.onnx` 512D Vector Generation)
3. `VectorIndexManager` (RAM Cosine Similarity Search < 20 ms)
4. Glowing Neon Recognition HUD Overlay with Person Labels
