# FaceVault AI — Local Recognition Engine Specification

> **Version**: 3.0 (Phase 3A Implementation)
> **Engine**: `LocalRecognitionEngineImpl`

---

## 1. Overview & Data Flow

`LocalRecognitionEngineImpl` integrates ONNX model execution, embedding normalization, and RAM vector indexing into a clean service interface.

```
Face Image Bytes / Tensor
          │
          ▼
ModelLoader (ONNX Session)
          │
          ▼
EmbeddingGenerator (512-dim Float32 L2 Norm)
          │
          ▼
VectorIndexManager (RAM Dot Product Search < 20 ms)
          │
          ▼
LocalRecognitionResult (Person ID, Name, Confidence %, Similarity)
```

---

## 2. Match Evaluation & Thresholds

- **Similarity Threshold**: `0.45` (`EdgeAiConfig.similarityThreshold`)
- **Confidence Formula**: $\text{Confidence} = (\text{Similarity} \times 100)\%$
- **Distance Formula**: $\text{Distance} = 1.0 - \text{Similarity}$

---

## 3. Preparation for Phase 3B (Live Camera Stream Integration)

In **Phase 3B**, the live camera feed will invoke `LocalRecognitionEngineImpl` via background isolates (`compute` / `Isolate.run`), passing camera YUV420 frame buffers for real-time live recognition HUD rendering.
