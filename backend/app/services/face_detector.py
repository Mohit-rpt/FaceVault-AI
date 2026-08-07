"""
Face Detection Service using InsightFace (Memory & Singleton Optimized).

Detects faces, returns bounding boxes, landmarks, crops, AND embeddings.
"""
import os
import logging
from typing import List, Optional

# Optimize ONNX Runtime & BLAS thread allocation to prevent Render 512MB RAM OOM
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"
os.environ["OPENBLAS_NUM_THREADS"] = "1"
os.environ["VECLIB_MAXIMUM_THREADS"] = "1"
os.environ["NUMEXPR_NUM_THREADS"] = "1"
os.environ["ORT_INTRA_OP_NUM_THREADS"] = "1"
os.environ["ORT_INTER_OP_NUM_THREADS"] = "1"

import numpy as np
from insightface.app import FaceAnalysis
from pydantic import BaseModel, ConfigDict

from .exceptions import InvalidImageError, NoFaceDetectedError
from .image_validator import ImageValidator
from .image_quality import ImageQualityAssessor

logger = logging.getLogger(__name__)


class FaceDetectionResult(BaseModel):
    """Structured result for a single detected face."""
    model_config = ConfigDict(arbitrary_types_allowed=True)

    bounding_box: List[float]
    landmarks: Optional[List[List[float]]]
    detection_score: float
    face_image: np.ndarray
    embedding: Optional[np.ndarray] = None


class FaceDetector:
    """
    InsightFace-based face detector with validation, quality checks, and memory management.
    """

    def __init__(
        self,
        model_name: str = "buffalo_sc",
        ctx_id: int = -1,
        det_size: tuple = (320, 320),
        validator: Optional[ImageValidator] = None,
        quality_assessor: Optional[ImageQualityAssessor] = None,
    ):
        self.validator = validator or ImageValidator()
        self.quality = quality_assessor or ImageQualityAssessor()

        self.app = FaceAnalysis(
            name=model_name,
            providers=["CPUExecutionProvider"],
            allowed_modules=["detection", "recognition"],
        )
        self.app.prepare(ctx_id=ctx_id, det_size=det_size)

        logger.info("✅ InsightFace singleton initialized")
        logger.info(f"✅ {model_name} loaded")
        logger.info("✅ ONNX Runtime initialized")

    def detect(self, image: np.ndarray) -> List[FaceDetectionResult]:
        """Detect faces with validation, quality checks, and memory optimization."""
        self.validator.validate_or_raise(image)

        faces = self.app.get(image)
        if not faces:
            raise NoFaceDetectedError("No faces detected in image")

        results = []
        for face in faces:
            try:
                x1, y1, x2, y2 = map(int, face.bbox)
                h, w = image.shape[:2]
                x1, y1 = max(0, x1), max(0, y1)
                x2, y2 = min(w, x2), min(h, y2)

                if x2 <= x1 or y2 <= y1:
                    continue

                crop = image[y1:y2, x1:x2].copy()

                # Quality check on cropped face
                self.quality.check(crop, face_bbox=face.bbox)

                # Landmarks in crop coordinates
                landmarks = None
                if hasattr(face, "kps") and face.kps is not None:
                    adjusted = face.kps.copy()
                    adjusted[:, 0] -= x1
                    adjusted[:, 1] -= y1
                    landmarks = adjusted.tolist()

                # Direct embedding from InsightFace face object
                raw_embedding = None
                if hasattr(face, "embedding") and face.embedding is not None:
                    raw_embedding = face.embedding.copy()

                results.append(
                    FaceDetectionResult(
                        bounding_box=face.bbox.astype(float).tolist(),
                        landmarks=landmarks,
                        detection_score=float(face.det_score),
                        face_image=crop,
                        embedding=raw_embedding,
                    )
                )
            except Exception as e:
                logger.warning(f"Skipping detected face due to error: {e}")
                continue

        if not results:
            raise NoFaceDetectedError("Faces detected but failed quality/validation checks")

        return results

    def detect_single(self, image: np.ndarray) -> Optional[FaceDetectionResult]:
        """Detect single best face."""
        try:
            faces = self.detect(image)
            return max(faces, key=lambda f: f.detection_score) if faces else None
        except NoFaceDetectedError:
            return None