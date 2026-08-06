"""
Similarity Engine with Abstract Interface.

Supports pluggable backends: Vectorized PostgreSQL/NumPy (now) and FAISS (later).
"""

import logging
from abc import ABC, abstractmethod
from typing import List, Optional, Tuple

import numpy as np
from sqlalchemy.orm import Session

from app.models.models import FaceEmbedding, Setting
from .exceptions import DatabaseLookupError
from .embedding_normalizer import EmbeddingNormalizer

logger = logging.getLogger(__name__)


class MatchResult:
    """Match result container."""
    def __init__(self, person_id: int, embedding_id: int, similarity: float, confidence: float, matched: bool):
        self.person_id = person_id
        self.embedding_id = embedding_id
        self.similarity = float(similarity)
        self.confidence = float(confidence)
        self.matched = bool(matched)

    def __repr__(self):
        return f"MatchResult(pid={self.person_id}, sim={self.similarity:.4f}, matched={self.matched})"


class BaseSimilarityEngine(ABC):
    """Abstract base class for similarity engines."""

    @abstractmethod
    def load_embeddings(self) -> None:
        """Load embeddings into memory/index."""
        pass

    @abstractmethod
    def clear_cache(self) -> None:
        """Clear cached embeddings."""
        pass

    @abstractmethod
    def compare_embedding(self, query: np.ndarray, top_k: int = 1) -> List[MatchResult]:
        """Compare query embedding against database."""
        pass

    @abstractmethod
    def find_best_match(self, query: np.ndarray) -> Optional[MatchResult]:
        """Find single best match."""
        pass

    @abstractmethod
    def add_embedding(self, person_id: int, embedding_id: int, vector: np.ndarray) -> None:
        """Add new embedding to index."""
        pass

    @abstractmethod
    def remove_embedding(self, embedding_id: int) -> None:
        """Remove embedding from index."""
        pass


class CosineSimilarityEngine(BaseSimilarityEngine):
    """
    High-performance Vectorized Cosine Similarity Engine.
    Uses BLAS/NumPy 2D matrix multiplication for instant vector comparisons.
    """

    DEFAULT_THRESHOLD = 0.60

    def __init__(self, db: Session):
        self.db = db
        self._threshold: Optional[float] = None
        self._metadata: List[Tuple[int, int]] = []  # List of (person_id, embedding_id)
        self._matrix: Optional[np.ndarray] = None   # Shape: (N, Dimension)
        self.normalizer = EmbeddingNormalizer()

    def get_threshold(self) -> float:
        """Get or cache threshold setting."""
        if self._threshold is not None:
            return self._threshold
        try:
            s = self.db.query(Setting).filter(Setting.setting_key == "recognition_threshold").first()
            val = float(s.setting_value) if s and s.setting_value else self.DEFAULT_THRESHOLD
            # DB setting store as 0-100 or 0-1
            self._threshold = val / 100.0 if val > 1.0 else val
        except Exception as e:
            logger.error(f"Threshold load failed: {e}")
            self._threshold = self.DEFAULT_THRESHOLD
        return self._threshold

    def load_embeddings(self) -> None:
        """Load and vectorize all active embeddings from DB."""
        logger.info("Loading face embeddings into vector matrix")
        try:
            rows = self.db.query(FaceEmbedding).filter(FaceEmbedding.is_active == True).all()
        except Exception as e:
            raise DatabaseLookupError(f"DB error loading embeddings: {e}")

        metadata = []
        vectors = []

        for row in rows:
            if not row.embedding_vector:
                continue
            try:
                vec = self.normalizer.from_bytes(row.embedding_vector, row.embedding_dimension or 512)
                vec = self.normalizer.normalize(vec)
                vectors.append(vec)
                metadata.append((row.person_id, row.embedding_id))
            except Exception as e:
                logger.warning(f"Skipped corrupt embedding {row.embedding_id}: {e}")

        self._metadata = metadata
        if vectors:
            self._matrix = np.vstack(vectors).astype(np.float32)
        else:
            self._matrix = None

        logger.info(f"Vector matrix initialized with {len(metadata)} face embeddings")

    def clear_cache(self) -> None:
        self._metadata = []
        self._matrix = None
        self._threshold = None
        logger.info("Embedding vector matrix cache cleared")

    @staticmethod
    def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
        return float(np.dot(a, b))

    def compare_embedding(self, query: np.ndarray, top_k: int = 1) -> List[MatchResult]:
        """Vectorized cosine similarity comparison via matrix-vector multiplication."""
        if self._matrix is None or len(self._metadata) == 0:
            self.load_embeddings()

        if self._matrix is None or len(self._metadata) == 0:
            return []

        query = self.normalizer.normalize(query)
        threshold = self.get_threshold()

        # Single vectorized BLAS dot product: (N, D) dot (D,) -> (N,)
        similarities = np.dot(self._matrix, query)
        similarities = np.clip(similarities, 0.0, 1.0)

        # Get top-k indices
        top_k = min(top_k, len(similarities))
        top_indices = np.argsort(similarities)[::-1][:top_k]

        matches = []
        for idx in top_indices:
            sim = float(similarities[idx])
            pid, eid = self._metadata[idx]
            matches.append(MatchResult(pid, eid, sim, sim * 100.0, sim >= threshold))

        return matches

    def find_best_match(self, query: np.ndarray) -> Optional[MatchResult]:
        matches = self.compare_embedding(query, top_k=1)
        if not matches or not matches[0].matched:
            return None
        return matches[0]

    def add_embedding(self, person_id: int, embedding_id: int, vector: np.ndarray) -> None:
        vec = self.normalizer.normalize(vector).reshape(1, -1).astype(np.float32)
        self._metadata.append((person_id, embedding_id))
        if self._matrix is None:
            self._matrix = vec
        else:
            self._matrix = np.vstack([self._matrix, vec])
        logger.debug(f"Added embedding_id={embedding_id} to matrix index")

    def remove_embedding(self, embedding_id: int) -> None:
        if not self._metadata:
            return
        indices = [i for i, meta in enumerate(self._metadata) if meta[1] != embedding_id]
        self._metadata = [self._metadata[i] for i in indices]
        if indices and self._matrix is not None:
            self._matrix = self._matrix[indices]
        else:
            self._matrix = None
        logger.debug(f"Removed embedding_id={embedding_id} from matrix index")