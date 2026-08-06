from app.services.face_detector import FaceDetector

_face_detector = None


def get_face_detector():
    global _face_detector

    if _face_detector is None:
        _face_detector = FaceDetector()

    return _face_detector
