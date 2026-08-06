"""
Shared protocols and types for the Face Recognition Engine.

Defines interfaces that allow swapping backends (e.g., PostgreSQL brute-force
→ FAISS) without changing RecognitionService.
"""

from dataclasses import dataclass
from typing import List, Optional, Protocol

import numpy as np


@dataclass
class SearchResult:
    """Result from vector similarity search."""
    person_id: int
    embedding_id: int
    score: float  # Cosine similarity (0.0 to 1.0)
    matched: bool  # Whether score exceeds threshold


class VectorSearchBackend(Protocol):
    """
    Protocol for vector similarity search backends.
    
    Both PostgreSQL brute-force and FAISS implementations must conform.
    """
    
    def search(self, query_vector: np.ndarray, top_k: int = 1) -> List[SearchResult]:
        """
        Search for nearest neighbors.
        
        Args:
            query_vector: Query embedding vector.
            top_k: Number of top results to return.
            
        Returns:
            List of SearchResult, sorted by score descending.
        """
        ...
    
    def add_vector(self, person_id: int, embedding_id: int, vector: np.ndarray) -> None:
        """Add a new vector to the index."""
        ...
    
    def remove_vector(self, embedding_id: int) -> None:
        """Remove a vector from the index."""
        ...
    
    def rebuild(self) -> None:
        """Rebuild the entire search index."""
        ...
    
    def clear_cache(self) -> None:
        """Clear any cached data."""
        ...
    
    def get_threshold(self) -> float:
        """Get current recognition threshold."""
        ...
    
    def set_threshold(self, threshold: float) -> None:
        """Update recognition threshold."""
        ...