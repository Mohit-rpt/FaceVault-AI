"""
Face Embedding Service using InsightFace.

Generates 512-dim embeddings with alignment and normalization.
"""

import logging
from typing import Optional

import numpy as np
from pydantic import BaseModel, ConfigDict

from .exceptions import EmbeddingGenerationError
from .embedding_normalizer import EmbeddingNormalizer

logger = logging.getLogger(__name__)


class EmbeddingResult(BaseModel):
    """Generated embedding result."""
    model_config = ConfigDict(arbitrary_types_allowed=True)
    
    embedding: np.ndarray
    model_name: str
    dimension: int


class EmbeddingService:
    EMBEDDING_DIMENSION = 512
    
    def __init__(self, normalizer: Optional[EmbeddingNormalizer] = None):
        self.normalizer = normalizer or EmbeddingNormalizer(expected_dim=self.EMBEDDING_DIMENSION)
        logger.info("EmbeddingService ready (normalization only)")

    def get_embedding(self, raw_embedding: np.ndarray) -> EmbeddingResult:
        if raw_embedding is None or not isinstance(raw_embedding, np.ndarray):
            raise EmbeddingGenerationError("No embedding provided")
        normalized = self.normalizer.normalize(raw_embedding)
        return EmbeddingResult(
            embedding=normalized,
            model_name="buffalo_sc",
            dimension=normalized.shape[0],
        )