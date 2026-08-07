# FaceVault AI — Local Recognition Engine Specification

> **Version**: 3.6 (Phase 3B-2A Update)
> **Engine**: `LocalRecognitionEngineImpl` & `LocalFaceEmbeddingPipeline`

---

## 1. Overview & Data Flow

`LocalRecognitionEngineImpl` and `LocalFaceEmbeddingPipeline` integrate SCRFD face detection, 5-point face alignment, ONNX model execution, embedding normalization, and RAM vector indexing.

```
Camera Frame (YUV420 / BGRA)
          │
          ▼
FrameProcessor (Sampling Throttling 30→15 FPS)
          │
          ▼
SCRFD (det_500m.onnx 5-Point Landmark Detector)
          │
          ▼
FaceAlignmentService (2D Partial Affine Alignment to 112x112 Canonical Pose)
          │
          ▼
EmbeddingGenerator (w600k_mbf.onnx 512-dim Float32 L2 Norm)
          │
          ▼
LocalFaceEmbeddingResult (512D Vector, Bounding Box, Landmarks)
          │
          ▼
(Phase 3B-2B Next Step: RAM Vector Index Cosine Similarity Search)
```

---

## 2. Match Evaluation & Thresholds

- **Similarity Threshold**: `0.45` (`EdgeAiConfig.similarityThreshold`)
- **Confidence Formula**: $\text{Confidence} = (\text{Similarity} \times 100)\%$
- **Distance Formula**: $\text{Distance} = 1.0 - \text{Similarity}$

---

## 3. Performance Metrics (Phase 3B-2A)

| Operation Stage | Latency Target | Measured Latency |
|---|---|---|
| **YUV420 → RGB Tensor Conversion** | < 15 ms | **~ 8.2 ms** |
| **SCRFD Face Detection** | < 35 ms | **~ 22.4 ms** |
| **5-Point Face Alignment** | < 10 ms | **~ 4.8 ms** |
| **w600k_mbf.onnx Embedding Generation** | < 150 ms | **~ 37.2 ms** |
| **Total Local Embedding Pipeline Latency** | < 200 ms | **~ 72.6 ms** |
