import threading
from app.services.face_detector import FaceDetector

_face_detector = None
_lock = threading.Lock()


def get_face_detector() -> FaceDetector:
    """
    Thread-safe Singleton accessor for loaded InsightFace FaceDetector model.
    Guarantees only ONE model instance exists in memory across the entire backend process.
    """
    global _face_detector

    if _face_detector is None:
        with _lock:
            if _face_detector is None:
                _face_detector = FaceDetector()

    return _face_detector
