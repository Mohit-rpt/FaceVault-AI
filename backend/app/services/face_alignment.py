"""
Face Alignment Service.

Aligns detected faces using facial landmarks (eyes) to a canonical pose
before embedding generation. Improves recognition accuracy.
"""

import logging
from typing import List, Optional

import cv2
import numpy as np

from .exceptions import FaceAlignmentError

logger = logging.getLogger(__name__)


class FaceAlignment:
    """
    Reusable face alignment service.
    
    Uses 5-point landmarks (eyes, nose, mouth corners) from InsightFace
    to apply similarity transform and align face to standard position.
    """
    
    # Standard 5 landmarks for aligned face (eyes, nose, mouth corners)
    # These are normalized coordinates for a 112x112 face template
    DEFAULT_TARGET_LANDMARKS = np.array([
        [38.2946, 51.6963],   # Left eye
        [73.5318, 51.5014],   # Right eye
        [56.0252, 71.7366],   # Nose
        [41.5493, 92.3655],   # Left mouth
        [70.7299, 92.2041],   # Right mouth
    ], dtype=np.float32)
    
    def __init__(
        self,
        target_size: int = 112,
        target_landmarks: Optional[np.ndarray] = None,
    ):
        self.target_size = target_size
        self.target_landmarks = target_landmarks or self.DEFAULT_TARGET_LANDMARKS.copy()
        
        # Scale landmarks to target size if needed
        if target_size != 112:
            scale = target_size / 112.0
            self.target_landmarks = self.target_landmarks * scale
        
        logger.info(f"FaceAlignment initialized with target size: {target_size}")

    def align(
        self,
        image: np.ndarray,
        landmarks: np.ndarray,
    ) -> np.ndarray:
        """
        Align face image using 5-point landmarks.
        
        Args:
            image: Original image containing the face.
            landmarks: 5 facial landmarks from InsightFace (shape: 5x2).
                       Order: left_eye, right_eye, nose, left_mouth, right_mouth
            
        Returns:
            Aligned face image as NumPy array.
            
        Raises:
            FaceAlignmentError: If alignment fails.
        """
        if landmarks is None or len(landmarks) < 5:
            raise FaceAlignmentError("Insufficient landmarks for alignment. Need at least 5 points.")
        
        # Use first 5 landmarks
        src = np.array(landmarks[:5], dtype=np.float32)
        dst = self.target_landmarks.astype(np.float32)
        
        # Validate
        if src.shape != (5, 2):
            raise FaceAlignmentError(f"Invalid landmarks shape: {src.shape}. Expected (5, 2).")
        
        try:
            # Estimate similarity transform (scale, rotation, translation)
            # Using estimateRigidTransform or getAffineTransform
            # For 5 points, we use estimateAffinePartial2D for similarity
            transform_matrix, inliers = cv2.estimateAffinePartial2D(
                src.reshape(-1, 1, 2),
                dst.reshape(-1, 1, 2),
                method=cv2.LMEDS,
            )
            
            if transform_matrix is None:
                raise FaceAlignmentError("Failed to estimate alignment transform")
            
            # Apply affine warp
            aligned = cv2.warpAffine(
                image,
                transform_matrix,
                (self.target_size, self.target_size),
                borderValue=0.0,
            )
            
            if aligned is None or aligned.size == 0:
                raise FaceAlignmentError("Warp affine produced empty image")
            
            logger.debug(f"Face aligned to {self.target_size}x{self.target_size}")
            return aligned
            
        except FaceAlignmentError:
            raise
        except Exception as e:
            logger.error(f"Face alignment failed: {e}")
            raise FaceAlignmentError(f"Alignment error: {e}") from e

    def align_from_detection(
        self,
        image: np.ndarray,
        bbox: np.ndarray,
        landmarks: np.ndarray,
        margin: float = 0.2,
    ) -> np.ndarray:
        """
        Crop face with margin and then align.
        
        Args:
            image: Original image.
            bbox: Bounding box [x1, y1, x2, y2].
            landmarks: 5-point landmarks.
            margin: Margin factor around face before alignment.
            
        Returns:
            Aligned face crop.
        """
        h, w = image.shape[:2]
        x1, y1, x2, y2 = map(float, bbox)
        
        # Add margin
        width = x2 - x1
        height = y2 - y1
        x1 = max(0, int(x1 - margin * width))
        y1 = max(0, int(y1 - margin * height))
        x2 = min(w, int(x2 + margin * width))
        y2 = min(h, int(y2 + margin * height))
        
        face_crop = image[y1:y2, x1:x2]
        
        # Adjust landmarks to cropped coordinates
        adjusted_landmarks = landmarks.copy()
        adjusted_landmarks[:, 0] -= x1
        adjusted_landmarks[:, 1] -= y1
        
        return self.align(face_crop, adjusted_landmarks)