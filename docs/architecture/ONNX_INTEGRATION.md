# FaceVault AI — ONNX Runtime Mobile Integration Specification

> **Version**: 3.0 (Phase 3A Implementation)
> **Engine**: ONNX Runtime Flutter (`onnxruntime: ^1.4.1`)

---

## 1. Overview & Architecture

The ONNX Runtime Mobile Integration provides high-performance, on-device AI inference for face embedding generation in Flutter without relying on backend API calls.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          ONNX RUNTIME INTEGRATION                           │
│                                                                             │
│  ┌───────────────────────────────┐     ┌─────────────────────────────────┐  │
│  │          ModelLoader          │────>│       EmbeddingGenerator        │  │
│  │ (OrtSession & OrtEnv Manager) │     │ (Inference & L2 Normalization)  │  │
│  └───────────────┬───────────────┘     └────────────────┬────────────────┘  │
│                  │                                      │                   │
│                  ▼                                      ▼                   │
│  ┌───────────────────────────────┐     ┌─────────────────────────────────┐  │
│  │    assets/models/             │     │ Output 512-dim Float32Vector    │  │
│  │    w600k_mbf.onnx (14.6 MB)   │     │ v = v / sqrt(sum(v_i^2))        │  │
│  └───────────────────────────────┘     └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Model Parameters & Input/Output Specs

- **Model Pack**: `buffalo_sc` (`w600k_mbf.onnx` MobileFaceNet / ResNet recognition model)
- **Input Tensor Shape**: `[1, 3, 112, 112]` (Float32 NCHW tensor)
- **Output Tensor Shape**: `[1, 512]` (Float32 embedding vector)
- **Execution Provider**: `CPUExecutionProvider`
- **Thread Allocation**: Single-threaded intra-op (`setIntraOpNumThreads(1)`) & inter-op (`setInterOpNumThreads(1)`) allocation for mobile RAM optimization (< 15 MB footprint).

---

## 3. Preprocessing & Normalization Protocol

1. **Face Alignment**: Crops and resizes detected face to canonical $112 \times 112$ pixels.
2. **Channel Format**: Normalizes RGB color channels into 3-channel NCHW float values.
3. **L2 Normalization Formula**:
   $$v_{\text{normalized}} = \frac{v}{\sqrt{\sum_{i=1}^{512} v_i^2}}$$

---

## 4. Performance Expectations

| Device Tier | Target Inference Latency | Target Memory Footprint |
|---|---|---|
| High-End Smartphone | < 45 ms | ~ 14.6 MB |
| Mid-Range Smartphone | < 95 ms | ~ 14.6 MB |
| Entry-Level Mobile | < 145 ms | ~ 14.6 MB |
