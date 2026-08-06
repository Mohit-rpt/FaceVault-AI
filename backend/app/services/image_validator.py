"""
Image Validation Service.

Validates image format, dimensions, channels, and integrity
before passing to downstream services.
"""

import logging
from typing import Optional, Tuple

import numpy as np
from pydantic import BaseModel

from .exceptions import InvalidImageError

logger = logging.getLogger(__name__)


class ValidationResult(BaseModel):
    """Result of image validation."""
    valid: bool
    message: str
    shape: Optional[Tuple[int, ...]] = None
    channels: Optional[int] = None
    dtype: Optional[str] = None


class ImageValidator:
    """
    Reusable image validator.
    
    Checks:
    - NumPy array type
    - Non-empty
    - Valid dimensions (2D or 3D)
    - Valid channels (1, 3, or 4)
    - Minimum size thresholds
    - Non-corrupted data (NaN/Inf)
    """
    
    def __init__(
        self,
        min_width: int = 64,
        min_height: int = 64,
        max_width: int = 4096,
        max_height: int = 4096,
        allowed_channels: Tuple[int, ...] = (1, 3, 4),
    ):
        self.min_width = min_width
        self.min_height = min_height
        self.max_width = max_width
        self.max_height = max_height
        self.allowed_channels = allowed_channels

    def validate(self, image: np.ndarray) -> ValidationResult:
        """
        Validate image and return structured result.
        
        Does NOT raise — returns result for conditional handling.
        """
        # Type check
        if not isinstance(image, np.ndarray):
            return ValidationResult(valid=False, message="Input must be a NumPy array")
        
        # Empty check
        if image.size == 0:
            return ValidationResult(valid=False, message="Image array is empty")
        
        # Dimension check
        if len(image.shape) not in (2, 3):
            return ValidationResult(
                valid=False,
                message=f"Invalid dimensions: {len(image.shape)}. Expected 2 or 3.",
                shape=image.shape,
            )
        
        # Channels check
        channels = 1 if len(image.shape) == 2 else image.shape[2]
        if channels not in self.allowed_channels:
            return ValidationResult(
                valid=False,
                message=f"Invalid channels: {channels}. Allowed: {self.allowed_channels}",
                shape=image.shape,
                channels=channels,
            )
        
        # Size check
        h, w = image.shape[:2]
        if w < self.min_width or h < self.min_height:
            return ValidationResult(
                valid=False,
                message=f"Image too small: {w}x{h}. Min: {self.min_width}x{self.min_height}",
                shape=image.shape,
            )
        if w > self.max_width or h > self.max_height:
            return ValidationResult(
                valid=False,
                message=f"Image too large: {w}x{h}. Max: {self.max_width}x{self.max_height}",
                shape=image.shape,
            )
        
        # Data integrity check
        if np.isnan(image).any():
            return ValidationResult(valid=False, message="Image contains NaN values", shape=image.shape)
        if np.isinf(image).any():
            return ValidationResult(valid=False, message="Image contains Inf values", shape=image.shape)
        
        return ValidationResult(
            valid=True,
            message="Image is valid",
            shape=image.shape,
            channels=channels,
            dtype=str(image.dtype),
        )

    def validate_or_raise(self, image: np.ndarray) -> ValidationResult:
        """
        Validate image. Raise InvalidImageError if invalid.
        """
        result = self.validate(image)
        if not result.valid:
            logger.warning(f"Image validation failed: {result.message}")
            raise InvalidImageError(result.message)
        logger.debug(f"Image validation passed: {result.shape}")
        return result