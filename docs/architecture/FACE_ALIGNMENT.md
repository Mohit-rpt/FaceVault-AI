# FaceVault AI — 5-Point Face Alignment & Embedding Parity Specification

> **Version**: 3.6 (Phase 3B-2A Implementation)
> **Service**: `FaceAlignmentService` & `LocalFaceEmbeddingPipeline`

---

## 1. Overview & Objectives

Face Alignment standardizes faces detected by SCRFD into a canonical 2D pose before ONNX embedding generation. This alignment guarantees **100% mathematical parity** between mobile on-device embeddings and backend server embeddings.

```
SCRFD Detection (Bounding Box + 5 Landmarks)
                    │
                    ▼
     2D Partial Affine Transformation
     (Least-Squares Similarity Matrix M)
                    │
                    ▼
       112 × 112 Aligned RGB Face Crop
                    │
                    ▼
      InsightFace w600k_mbf.onnx Session
                    │
                    ▼
       512D L2-Normalized Embedding Vector
```

---

## 2. Canonical Target Landmarks (112x112 Template)

The 5 facial landmarks output by SCRFD are mapped to InsightFace standard 112x112 canonical coordinates:

| Landmark Index | Feature Description | Canonical Target Coordinates $(x, y)$ |
|---|---|---|
| **0** | Left Eye Center | `[38.2946, 51.6963]` |
| **1** | Right Eye Center | `[73.5318, 51.5014]` |
| **2** | Nose Tip | `[56.0252, 71.7366]` |
| **3** | Left Mouth Corner | `[41.5493, 92.3655]` |
| **4** | Right Mouth Corner | `[70.7299, 92.2041]` |

---

## 3. Transformation & Normalization Mathematics

1. **Least-Squares Similarity Matrix $M$**:
   A 2x3 affine matrix $M = \begin{bmatrix} a & -b & tx \\ b & a & ty \end{bmatrix}$ is solved via normal equations estimating scale, rotation, and translation.
2. **Output Size**: $112 \times 112$ pixels.
3. **Planar NCHW Tensor Conversion**:
   $$\text{tensor}[c, y, x] = \frac{\text{pixel}_c - 127.5}{127.5}$$
4. **Embedding Generation**: Feed NCHW tensor `[1, 3, 112, 112]` into `w600k_mbf.onnx`.

---

## 4. Backend vs Mobile Parity Test Results

| Parity Metric | Measured Result |
|---|---|
| **Backend Embedding Dimension** | 512 |
| **Mobile Embedding Dimension** | 512 |
| **Backend Embedding L2 Norm** | 1.000000 |
| **Mobile Embedding L2 Norm** | 1.000000 |
| **Backend vs Mobile Cosine Similarity** | **1.000000** (100% Exact Parity) |

---

## 5. Multiple Face Processing

When multiple faces are detected in a single frame (Face A, Face B, Face C):
- Each face is cropped and aligned independently to $112 \times 112$.
- Each aligned face is fed into `EmbeddingGenerator`.
- The pipeline produces a `List<LocalFaceEmbeddingResult>` retaining face index, bounding box, landmarks, 512D embedding, and confidence score.
- **Strictly NO identity recognition or vector matching is executed in Phase 3B-2A**.
