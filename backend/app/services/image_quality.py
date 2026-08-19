"""
Image Quality Assessment Service.

Assesses blur, brightness, contrast, and face-to-image ratio
to reject low-quality images before embedding.
"""

import logging
from typing import Optional

import cv2
import numpy as np
from pydantic import BaseModel

from .exceptions import ImageQualityError

logger = logging.getLogger(__name__)


class QualityMetrics(BaseModel):
    """Computed quality metrics."""
    blur_score: float          # Laplacian variance (higher = sharper)
    brightness: float          # Mean pixel value (0-255)
    contrast: float            # Standard deviation
    face_ratio: Optional[float] = None  # Face area / Image area


class QualityThresholds(BaseModel):
    """Configurable quality thresholds."""
    min_blur: float = 10.0  # Temporarily lowered from 100.0 for mobile debugging
    min_brightness: float = 30.0
    max_brightness: float = 220.0
    min_contrast: float = 20.0
    min_face_ratio: float = 0.01  # Face must be at least 1% of image


class ImageQualityAssessor:
    """
    Reusable image quality assessor.
    
    Checks:
    - Blur (Laplacian variance)
    - Brightness (mean pixel intensity)
    - Contrast (standard deviation)
    - Face-to-image ratio (optional, if bbox provided)
    """
    
    def __init__(self, thresholds: Optional[QualityThresholds] = None):
        self.thresholds = thresholds or QualityThresholds()

    def assess(self, image: np.ndarray, face_bbox: Optional[np.ndarray] = None) -> QualityMetrics:
        """
        Compute quality metrics for an image.
        
        Args:
            image: Input image (BGR or grayscale).
            face_bbox: Optional bounding box [x1, y1, x2, y2] to compute face ratio.
            
        Returns:
            QualityMetrics object.
        """
        # Convert to grayscale for analysis
        if len(image.shape) == 3:
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        else:
            gray = image
        
        # Blur: Laplacian variance
        blur_score = float(cv2.Laplacian(gray, cv2.CV_64F).var())
        
        # Brightness: mean intensity
        brightness = float(np.mean(gray))
        
        # Contrast: standard deviation
        contrast = float(np.std(gray))
        
        # Face ratio
        face_ratio = None
        if face_bbox is not None:
            x1, y1, x2, y2 = face_bbox
            face_area = abs((x2 - x1) * (y2 - y1))
            img_area = image.shape[0] * image.shape[1]
            if img_area > 0:
                face_ratio = face_area / img_area
        
        metrics = QualityMetrics(
            blur_score=blur_score,
            brightness=brightness,
            contrast=contrast,
            face_ratio=face_ratio,
        )
        
        logger.debug(f"Quality metrics: blur={blur_score:.2f}, brightness={brightness:.2f}, contrast={contrast:.2f}")
        return metrics

    def check(self, image: np.ndarray, face_bbox: Optional[np.ndarray] = None) -> QualityMetrics:
        """
        Assess quality and raise ImageQualityError if below thresholds.
        
        Returns:
            QualityMetrics if passed.
            
        Raises:
            ImageQualityError: If any metric fails.
        """
        metrics = self.assess(image, face_bbox)
        failures = []
        
        if metrics.blur_score < self.thresholds.min_blur:
            failures.append(f"Too blurry (score={metrics.blur_score:.2f}, min={self.thresholds.min_blur})")
        
        if metrics.brightness < self.thresholds.min_brightness:
            failures.append(f"Too dark (brightness={metrics.brightness:.2f})")
        
        if metrics.brightness > self.thresholds.max_brightness:
            failures.append(f"Too bright (brightness={metrics.brightness:.2f})")
        
        if metrics.contrast < self.thresholds.min_contrast:
            failures.append(f"Too low contrast (contrast={metrics.contrast:.2f})")
        
        if metrics.face_ratio is not None and metrics.face_ratio < self.thresholds.min_face_ratio:
            failures.append(f"Face too small (ratio={metrics.face_ratio:.4f})")
        
        if failures:
            msg = "Image quality check failed: " + "; ".join(failures)
            logger.warning(msg)
            raise ImageQualityError(msg)
        
        logger.info("Image quality check passed")
        return metrics