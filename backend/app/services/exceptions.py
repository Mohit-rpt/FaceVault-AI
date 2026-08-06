"""Custom exceptions for Face Recognition Engine."""


class FaceRecognitionError(Exception):
    """Base exception."""
    pass


class InvalidImageError(FaceRecognitionError):
    """Raised when input image is invalid or corrupted."""
    pass


class ImageQualityError(FaceRecognitionError):
    """Raised when image quality is too low for processing."""
    pass


class NoFaceDetectedError(FaceRecognitionError):
    """Raised when no face is detected."""
    pass


class FaceAlignmentError(FaceRecognitionError):
    """Raised when face alignment fails."""
    pass


class EmbeddingGenerationError(FaceRecognitionError):
    """Raised when embedding generation fails."""
    pass


class EmbeddingNormalizationError(FaceRecognitionError):
    """Raised when embedding normalization fails."""
    pass


class DatabaseLookupError(FaceRecognitionError):
    """Raised when database query fails."""
    pass