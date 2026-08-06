"""
Recognition Service — Main orchestrator.

Uses dependency injection for all sub-services.
FAISS can be plugged in by passing a different BaseSimilarityEngine.
"""

import logging
import os
from datetime import datetime
from pathlib import Path
from typing import List, Optional

import cv2
import numpy as np
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.models.models import Person, FaceEmbedding, RecognitionLog

from .exceptions import FaceRecognitionError
from .face_detector import FaceDetector, FaceDetectionResult
from .embedding_service import EmbeddingService, EmbeddingResult
from .similarity import BaseSimilarityEngine, CosineSimilarityEngine, MatchResult
from .image_validator import ImageValidator
from .image_quality import ImageQualityAssessor
from .face_alignment import FaceAlignment
from .embedding_normalizer import EmbeddingNormalizer

logger = logging.getLogger(__name__)


class RecognizedFace(BaseModel):
    person_id: int
    person_name: str
    confidence: float
    similarity: float
    recognized: bool = True
    bounding_box: List[float]


class UnknownFace(BaseModel):
    confidence: float
    bounding_box: List[float]
    saved_path: Optional[str] = None


class RecognitionResult(BaseModel):
    recognized_faces: List[RecognizedFace]
    unknown_faces: List[UnknownFace]
    total_faces: int
    processing_time_ms: Optional[int] = None


class RecognitionService:
    """
    Main recognition orchestrator with full dependency injection.
    
    All sub-services are injectable. FAISS engine can replace CosineSimilarityEngine
    without any code changes here.
    """
    
    def __init__(
        self,
        db: Session,
        detector: FaceDetector,
        embedder: EmbeddingService,
        similarity_engine: Optional[BaseSimilarityEngine] = None,
        validator: Optional[ImageValidator] = None,
        quality_assessor: Optional[ImageQualityAssessor] = None,
        unknown_faces_dir: Optional[str] = None,
    ):
        self.db = db
        self.validator = validator or ImageValidator()
        self.quality = quality_assessor or ImageQualityAssessor()

        self.detector = detector
        self.embedder = embedder

        self.similarity = similarity_engine or CosineSimilarityEngine(db)
        
        self.unknown_faces_dir = unknown_faces_dir or os.getenv("UNKNOWN_FACES_DIR", "storage/unknown_faces")
        Path(self.unknown_faces_dir).mkdir(parents=True, exist_ok=True)
        self._name_cache: dict = {}
        
        logger.info("RecognitionService initialized")

    def _save_unknown(self, face_image: np.ndarray, embedding: np.ndarray) -> str:
        ts = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        img_path = os.path.join(self.unknown_faces_dir, f"unknown_{ts}.jpg")
        emb_path = os.path.join(self.unknown_faces_dir, f"unknown_{ts}.npy")
        cv2.imwrite(img_path, face_image)
        np.save(emb_path, embedding)
        return img_path

    def _get_person_name(self, person_id: int) -> str:
        if person_id in self._name_cache:
            return self._name_cache[person_id]
        try:
            p = self.db.query(Person).filter(Person.person_id == person_id).first()
            name = p.name if p else "Unknown"
            self._name_cache[person_id] = name
            return name
        except Exception as e:
            logger.error(e)
            return "Unknown"

    def _save_log(self, person_id: int, confidence: float, camera_source: Optional[str], time_ms: Optional[int]) -> None:
        try:
            self.db.add(RecognitionLog(
                person_id=person_id,
                confidence_score=confidence,
                camera_source=camera_source,
                recognition_time_ms=time_ms,
            ))
            self.db.commit()
        except Exception as e:
            self.db.rollback()
            logger.error(f"Log save failed: {e}")

    def recognize(
        self,
        image: np.ndarray,
        camera_source: Optional[str] = None,
        save_unknown: bool = True,
    ) -> RecognitionResult:
        """
        Full recognition pipeline.
        """
        import time
        start = time.time()
        
        self.validator.validate_or_raise(image)
        
        detected_faces = self.detector.detect(image)
        total = len(detected_faces)
        
        recognized: List[RecognizedFace] = []
        unknowns: List[UnknownFace] = []
        
        for face in detected_faces:
            try:
               if face.embedding is None:
                    raise FaceRecognitionError("Face detected but embedding not available")
               emb = self.embedder.get_embedding(face.embedding)
               match = self.similarity.find_best_match(emb.embedding)
                
               if match:
                    recognized.append(RecognizedFace(
                        person_id=match.person_id,
                        person_name=self._get_person_name(match.person_id),
                        confidence=round(match.confidence, 2),
                        similarity=round(match.similarity, 4),
                        bounding_box=face.bounding_box,
                    ))
                    self._save_log(match.person_id, match.confidence, camera_source, None)
               else:
                    uf = UnknownFace(
                        confidence=round(face.detection_score * 100, 2),
                        bounding_box=face.bounding_box,
                    )
                    if save_unknown:
                        uf.saved_path = self._save_unknown(face.face_image, emb.embedding)
                    unknowns.append(uf)
            except Exception as e:
                    logger.warning(f"Face processing error: {e}")
                    continue
        
        elapsed = int((time.time() - start) * 1000)
        return RecognitionResult(
            recognized_faces=recognized,
            unknown_faces=unknowns,
            total_faces=total,
            processing_time_ms=elapsed,
        )

    def recognize_single(self, image: np.ndarray, camera_source: Optional[str] = None) -> Optional[RecognizedFace]:
        result = self.recognize(image, camera_source)
        return result.recognized_faces[0] if result.recognized_faces else None

    def register_face(
        self,
        person_id: int,
        face_image: np.ndarray,
        model_name: str = "buffalo_l",
        capture_angle: Optional[str] = None,
        capture_source: Optional[str] = None,
        quality_score: Optional[float] = None,
    ) -> FaceEmbedding:
        """
        Reusable service function for face registration.
        """
        logger.info(f"Registering face for person_id={person_id}")
        
        person = self.db.query(Person).filter(Person.person_id == person_id).first()
        if not person:
            raise FaceRecognitionError(f"Person {person_id} not found")
        
        face = self.detector.detect_single(face_image)
        if not face:
            raise FaceRecognitionError("No face detected for registration")
        
        if face.embedding is None:
            raise FaceRecognitionError("Face detected but embedding not available")
        emb = self.embedder.get_embedding(face.embedding)
        
        try:
            db_emb = FaceEmbedding(
                person_id=person_id,
                faiss_vector_id=0,
                model_name=model_name,
                model_version="1.0",
                embedding_dimension=emb.dimension,
                quality_score=quality_score or face.detection_score,
                capture_angle=capture_angle,
                capture_source=capture_source,
                is_active=True,
                embedding_vector=EmbeddingNormalizer.to_bytes(emb.embedding),
            )
            self.db.add(db_emb)

            # Get embedding_id without committing
            self.db.flush()

            # Add to similarity index
            self.similarity.add_embedding(
                person_id,
                db_emb.embedding_id,
                emb.embedding,
            )

            # Commit only after both operations succeed
            self.db.commit()
            self.db.refresh(db_emb)

            logger.info(f"Registered embedding_id={db_emb.embedding_id}")
            return db_emb
        except Exception as e:
            self.db.rollback()
            raise FaceRecognitionError(f"Registration failed: {e}") from e