"""
Live Face Recognition Engine with Threading.

Recognition runs in background thread.
Display stays smooth at full FPS.
"""

import logging
import time
import threading
import queue
from dataclasses import dataclass
from typing import Callable, List, Optional

import cv2
import numpy as np
from sqlalchemy.orm import Session

from app.database.database import SessionLocal
from app.services import RecognitionService

logger = logging.getLogger(__name__)


@dataclass
class LiveFaceResult:
    """Result for a single face in a frame."""
    person_id: Optional[int]
    person_name: str
    confidence: float
    similarity: float
    bounding_box: List[float]
    is_known: bool


@dataclass
class FrameResult:
    """Complete result for one processed frame."""
    faces: List[LiveFaceResult]
    fps: float
    processing_time_ms: int


class LiveRecognitionEngine:
    """
    Real-time face recognition with threading.
    
    - Main thread: Capture + Display (smooth)
    - Worker thread: Recognition (heavy, non-blocking)
    """
    
    def __init__(
        self,
        process_every_n_frames: int = 5,
        camera_id: int = 0,
        stream_url: Optional[str] = None,
        display_size: tuple = (1280, 720),
        confidence_threshold: float = 60.0,
    ):
        self.process_every_n_frames = max(1, process_every_n_frames)
        self.camera_id = camera_id
        self.stream_url = stream_url
        self.display_size = display_size
        self.confidence_threshold = confidence_threshold
        
        # Threading
        self._result_queue = queue.Queue(maxsize=2)  # Latest 2 results only
        self._stop_event = threading.Event()
        self._worker_thread: Optional[threading.Thread] = None
        
        # Cache
        self._last_results: List[LiveFaceResult] = []
        self._last_fps = 0.0
        
        source_label = self.stream_url if self.stream_url else f"camera {self.camera_id}"
        logger.info(f"LiveRecognitionEngine initialized (every {self.process_every_n_frames} frames, source: {source_label})")

    def _recognition_worker(self, frame: np.ndarray) -> None:
        """Run recognition in background thread."""
        db = SessionLocal()
        try:
            service = RecognitionService(db=db)
            result = service.recognize(frame, camera_source="live_webcam", save_unknown=False)
            
            faces = []
            for face in result.recognized_faces:
                faces.append(LiveFaceResult(
                    person_id=face.person_id,
                    person_name=face.person_name,
                    confidence=face.confidence,
                    similarity=face.similarity,
                    bounding_box=face.bounding_box,
                    is_known=face.confidence >= self.confidence_threshold,
                ))
            
            for face in result.unknown_faces:
                faces.append(LiveFaceResult(
                    person_id=None,
                    person_name="Unknown",
                    confidence=face.confidence,
                    similarity=0.0,
                    bounding_box=face.bounding_box,
                    is_known=False,
                ))
            
            # Put result (drop old if queue full)
            try:
                self._result_queue.put_nowait(FrameResult(
                    faces=faces,
                    fps=1000.0 / max(result.processing_time_ms or 1, 1),
                    processing_time_ms=result.processing_time_ms or 0,
                ))
            except queue.Full:
                pass  # Drop old result
                
        except Exception as e:
            logger.error(f"Recognition worker error: {e}")
        finally:
            db.close()

    def _draw_box(self, frame: np.ndarray, bbox: List[float], color: tuple, thickness: int = 2) -> None:
        """Draw bounding box."""
        x1, y1, x2, y2 = map(int, bbox)
        cv2.rectangle(frame, (x1, y1), (x2, y2), color, thickness)

    def _draw_label(self, frame: np.ndarray, bbox: List[float], text: str, color: tuple) -> None:
        """Draw text label above box."""
        x1, y1, _, _ = map(int, bbox)
        font = cv2.FONT_HERSHEY_SIMPLEX
        scale = 0.5
        thick = 2
        
        (tw, th), _ = cv2.getTextSize(text, font, scale, thick)
        
        # Background
        cv2.rectangle(frame, (x1, y1 - th - 8), (x1 + tw + 10, y1), (0, 0, 0), -1)
        # Text
        cv2.putText(frame, text, (x1 + 5, y1 - 3), font, scale, color, thick)

    def _render(self, frame: np.ndarray, result: FrameResult) -> np.ndarray:
        """Draw overlays."""
        for face in result.faces:
            if face.is_known:
                color = (0, 255, 0)  # Green
                text = f"{face.person_name} {face.confidence:.0f}%"
            else:
                color = (0, 0, 255)  # Red
                text = f"Unknown {face.confidence:.0f}%"
            
            self._draw_box(frame, face.bounding_box, color)
            self._draw_label(frame, face.bounding_box, text, color)
        
        # FPS (top-left)
        fps_text = f"FPS: {result.fps:.1f} | {result.processing_time_ms}ms | Faces: {len(result.faces)}"
        cv2.putText(frame, fps_text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
        
        return frame

    def run(self, exit_key: str = 'q') -> None:
        """Start live recognition."""
        # Use stream URL if provided, otherwise fall back to local camera index
        source = self.stream_url if self.stream_url else self.camera_id
        cap = cv2.VideoCapture(source)
        
        if not cap.isOpened():
            raise RuntimeError(f"Cannot open camera source: {source}")
        
        # Low latency settings
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)  # Min buffer
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.display_size[0])
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.display_size[1])
        
        logger.info(f"Camera opened. Press '{exit_key}' to exit.")
        
        frame_count = 0
        display_fps = 0.0
        last_time = time.time()
        
        try:
            while not self._stop_event.is_set():
                ret, frame = cap.read()
                if not ret:
                    continue
                
                frame = cv2.resize(frame, self.display_size)
                frame_count += 1
                
                # Calculate display FPS
                now = time.time()
                if now - last_time >= 1.0:
                    display_fps = frame_count / (now - last_time)
                    frame_count = 0
                    last_time = now
                
                # Check for new recognition results
                try:
                    new_result = self._result_queue.get_nowait()
                    self._last_results = new_result.faces
                    self._last_fps = new_result.fps
                except queue.Empty:
                    pass
                
                # Start recognition in background every N frames
                if frame_count % self.process_every_n_frames == 0:
                    if self._worker_thread is None or not self._worker_thread.is_alive():
                        # Copy frame for thread
                        frame_copy = frame.copy()
                        self._worker_thread = threading.Thread(
                            target=self._recognition_worker,
                            args=(frame_copy,),
                            daemon=True,
                        )
                        self._worker_thread.start()
                
                # Render with cached results
                result = FrameResult(
                    faces=self._last_results,
                    fps=display_fps,
                    processing_time_ms=0,
                )
                display = self._render(frame.copy(), result)
                
                cv2.imshow("FaceVault AI - Live", display)
                
                if cv2.waitKey(1) & 0xFF == ord(exit_key):
                    break
                    
        finally:
            self._stop_event.set()
            cap.release()
            cv2.destroyAllWindows()
            logger.info("Stopped")

    def stop(self) -> None:
        """Stop recognition."""
        self._stop_event.set()