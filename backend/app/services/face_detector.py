"""
Face Detection Service using InsightFace.

Detects faces, returns bounding boxes, landmarks, crops, AND embeddings.
"""

import logging
from typing import List, Optional

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
    embedding: Optional[np.ndarray] = None  # 🔥 NEW: Direct embedding from InsightFace


class FaceDetector:
    """
    InsightFace-based face detector with validation and quality checks.
    """
    
    def __init__(
        self,
        model_name: str = "buffalo_s",
        ctx_id: int = -1,
        det_size: tuple = (640, 640),
        validator: Optional[ImageValidator] = None,
        quality_assessor: Optional[ImageQualityAssessor] = None,
    ):
        self.validator = validator or ImageValidator()
        self.quality = quality_assessor or ImageQualityAssessor()
        
        logger.info(f"Initializing FaceDetector: {model_name}")
        self.app = FaceAnalysis(name=model_name, providers=['CPUExecutionProvider'])
        self.app.prepare(ctx_id=ctx_id, det_size=det_size)
        logger.info("FaceDetector ready")

    def detect(self, image: np.ndarray) -> List[FaceDetectionResult]:
        """Detect all faces with validation and quality checks."""
        self.validator.validate_or_raise(image)
        
        faces = self.app.get(image)
        if not faces:
            raise NoFaceDetectedError("No faces detected")
        
        results = []
        for face in faces:
            try:
                x1, y1, x2, y2 = map(int, face.bbox)
                h, w = image.shape[:2]
                x1, y1 = max(0, x1), max(0, y1)
                x2, y2 = min(w, x2), min(h, y2)
                
                if x2 <= x1 or y2 <= y1:
                    continue
                
                crop = image[y1:y2, x1:x2]
                
                # Quality check on cropped face
                self.quality.check(crop, face_bbox=face.bbox)
                
                # Landmarks ko crop coordinates mein adjust karo
                landmarks = None
                if hasattr(face, 'kps') and face.kps is not None:
                    adjusted = face.kps.copy()
                    adjusted[:, 0] -= x1
                    adjusted[:, 1] -= y1
                    landmarks = adjusted.tolist()
                
                # 🔥 NEW: Embedding directly from InsightFace face object
                raw_embedding = None
                if hasattr(face, 'embedding') and face.embedding is not None:
                    raw_embedding = face.embedding.copy()
                    logger.debug(f"Embedding extracted: shape={raw_embedding.shape}")
                
                results.append(FaceDetectionResult(
                    bounding_box=face.bbox.astype(float).tolist(),
                    landmarks=landmarks,
                    detection_score=float(face.det_score),
                    face_image=crop,
                    embedding=raw_embedding,  # 🔥 NEW
                ))
            except Exception as e:
                logger.warning(f"Skipping face due to error: {e}")
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