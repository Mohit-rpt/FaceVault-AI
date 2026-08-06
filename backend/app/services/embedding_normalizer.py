"""
Embedding Normalization Service.

Handles L2 normalization, mean centering, and optional whitening
for face embeddings before storage and comparison.
"""

import logging
from typing import Optional

import numpy as np

from .exceptions import EmbeddingNormalizationError

logger = logging.getLogger(__name__)


class EmbeddingNormalizer:
    """
    Reusable embedding normalizer.
    
    Operations:
    - L2 Normalization (default, required for cosine similarity)
    - Mean centering (optional)
    - Standardization (optional)
    - Dimension validation
    """
    
    def __init__(
        self,
        expected_dim: int = 512,
        apply_l2: bool = True,
        apply_centering: bool = False,
        apply_standardization: bool = False,
        mean_vector: Optional[np.ndarray] = None,
        std_vector: Optional[np.ndarray] = None,
    ):
        self.expected_dim = expected_dim
        self.apply_l2 = apply_l2
        self.apply_centering = apply_centering
        self.apply_standardization = apply_standardization
        self.mean_vector = mean_vector
        self.std_vector = std_vector

    def validate(self, embedding: np.ndarray) -> None:
        """
        Validate embedding shape and values.
        
        Raises:
            EmbeddingNormalizationError: If invalid.
        """
        if not isinstance(embedding, np.ndarray):
            raise EmbeddingNormalizationError("Embedding must be a NumPy array")
        
        if embedding.ndim != 1:
            raise EmbeddingNormalizationError(f"Expected 1D array, got {embedding.ndim}D")
        
        if embedding.shape[0] != self.expected_dim:
            raise EmbeddingNormalizationError(
                f"Dimension mismatch: {embedding.shape[0]} != {self.expected_dim}"
            )
        
        if np.isnan(embedding).any():
            raise EmbeddingNormalizationError("Embedding contains NaN values")
        
        if np.isinf(embedding).any():
            raise EmbeddingNormalizationError("Embedding contains Inf values")

    def normalize(self, embedding: np.ndarray) -> np.ndarray:
        """
        Apply full normalization pipeline.
        
        Args:
            embedding: Raw embedding vector.
            
        Returns:
            Normalized embedding.
        """
        self.validate(embedding)
        
        result = embedding.astype(np.float32).copy()
        
        # Mean centering
        if self.apply_centering and self.mean_vector is not None:
            result = result - self.mean_vector
            logger.debug("Applied mean centering")
        
        # Standardization
        if self.apply_standardization and self.std_vector is not None:
            result = result / (self.std_vector + 1e-8)
            logger.debug("Applied standardization")
        
        # L2 Normalization (always last)
        if self.apply_l2:
            norm = np.linalg.norm(result)
            if norm == 0:
                logger.warning("Zero-norm embedding. Returning as-is.")
            else:
                result = result / norm
        
        return result

    def batch_normalize(self, embeddings: np.ndarray) -> np.ndarray:
        """
        Normalize a batch of embeddings.
        
        Args:
            embeddings: Array of shape (N, D).
            
        Returns:
            Normalized array of same shape.
        """
        if embeddings.ndim != 2:
            raise EmbeddingNormalizationError(f"Expected 2D batch, got {embeddings.ndim}D")
        
        return np.array([self.normalize(e) for e in embeddings])

    @staticmethod
    def to_bytes(embedding: np.ndarray) -> bytes:
        """
        Convert normalized embedding to bytes for DB storage.
        """
        return embedding.astype(np.float32).tobytes()

    @staticmethod
    def from_bytes(data: bytes, dimension: int = 512) -> np.ndarray:
        """
        Convert bytes back to numpy array.
        """
        arr = np.frombuffer(data, dtype=np.float32)
        if arr.shape[0] != dimension:
            raise EmbeddingNormalizationError(
                f"Byte array dimension {arr.shape[0]} != expected {dimension}"
            )
        return arr