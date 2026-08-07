"""
Camera Manager – Ultra-Fast, Low-Latency Stream Manager.

Supports:
- Mobile cameras (DroidCam, IP Webcam) via HTTP/HTTPS
- CCTV / IP cameras via RTSP
- Local webcams via integer index

Features:
- Non-blocking thread-safe frame acquisition
- Low-latency buffer clearing
- Instant JPEG encoding for API delivery
- Robust error recovery & auto-reconnect
"""

import logging
import os
import threading
import time
from dataclasses import dataclass
from enum import Enum
from typing import Optional, Tuple, Union

import cv2
import numpy as np

logger = logging.getLogger(__name__)

# Configure OpenCV FFmpeg to disable internal buffering for RTSP & HTTP streams
os.environ["OPENCV_FFMPEG_CAPTURE_OPTIONS"] = "rtsp_transport;tcp|fflags;nobuffer|max_delay;500000"


class CameraType(str, Enum):
    MOBILE = "mobile"
    CCTV = "cctv"
    LOCAL = "local"


class CameraState(str, Enum):
    DISCONNECTED = "disconnected"
    CONNECTING = "connecting"
    CONNECTED = "connected"
    ERROR = "error"
    RECONNECTING = "reconnecting"


@dataclass
class CameraStatus:
    """Snapshot of current camera state."""
    state: CameraState = CameraState.DISCONNECTED
    url: Optional[str] = None
    camera_type: Optional[CameraType] = None
    fps: float = 0.0
    resolution: Optional[Tuple[int, int]] = None  # (width, height)
    error: Optional[str] = None


class CameraManager:
    """
    Thread-safe singleton managing the camera stream lifecycle.
    """

    _instance: Optional["CameraManager"] = None
    _lock = threading.Lock()

    @classmethod
    def get_instance(cls) -> "CameraManager":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = cls()
        return cls._instance

    def __init__(self) -> None:
        self._cap: Optional[cv2.VideoCapture] = None
        self._status = CameraStatus()

        # Shared frame buffers
        self._frame_lock = threading.Lock()
        self._raw_frame: Optional[np.ndarray] = None
        self._jpeg_frame: Optional[bytes] = None
        self._frame_id: int = 0

        # Background worker thread
        self._stop_event = threading.Event()
        self._reader_thread: Optional[threading.Thread] = None

        # Performance & FPS tracking
        self._frame_count = 0
        self._fps_start = time.time()
        self._current_fps = 0.0

        # Reconnection parameters
        self._max_reconnect_attempts = 5
        self._reconnect_delay = 2.0

        logger.info("CameraManager initialized")

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def connect(self, url: str, camera_type: CameraType = CameraType.MOBILE) -> CameraStatus:
        """Connect to camera stream (Mobile HTTP, RTSP, or Local)."""
        self.disconnect()

        url_str = url.strip()
        self._status = CameraStatus(
            state=CameraState.CONNECTING,
            url=url_str,
            camera_type=camera_type,
        )

        logger.info(f"Connecting to camera stream ({camera_type.value}): {url_str}")

        try:
            source: Union[int, str] = int(url_str) if (camera_type == CameraType.LOCAL or url_str.isdigit()) else url_str
            cap = cv2.VideoCapture(source)

            # Minimal buffer to prevent latency accumulation
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

            if not cap.isOpened():
                raise ConnectionError(f"Cannot open camera: {url_str}")

            # Read test frame
            ret, frame = cap.read()
            if not ret or frame is None:
                cap.release()
                raise ConnectionError(f"Camera opened but no video frames received: {url_str}")

            self._cap = cap
            h, w = frame.shape[:2]

            self._status = CameraStatus(
                state=CameraState.CONNECTED,
                url=url_str,
                camera_type=camera_type,
                resolution=(w, h),
            )

            # Store initial frame
            _, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
            with self._frame_lock:
                self._raw_frame = frame
                self._jpeg_frame = buf.tobytes()
                self._frame_id = 1

            # Start background frame grabber
            self._stop_event.clear()
            self._frame_count = 0
            self._fps_start = time.time()
            self._reader_thread = threading.Thread(
                target=self._reader_loop, daemon=True, name="camera-reader"
            )
            self._reader_thread.start()

            logger.info(f"Camera connected successfully ({w}x{h}): {url_str}")

        except Exception as e:
            self._cleanup_resources()
            self._status = CameraStatus(
                state=CameraState.ERROR,
                url=url_str,
                camera_type=camera_type,
                error=str(e),
            )
            logger.error(f"Camera connection failed: {e}")

        return self._status

    def disconnect(self) -> CameraStatus:
        """Disconnect and stop reader thread."""
        self._stop_event.set()

        if self._reader_thread and self._reader_thread.is_alive():
            self._reader_thread.join(timeout=3.0)
        self._reader_thread = None

        self._cleanup_resources()

        with self._frame_lock:
            self._raw_frame = None
            self._jpeg_frame = None
            self._frame_id = 0

        self._status = CameraStatus(state=CameraState.DISCONNECTED)
        self._current_fps = 0.0
        logger.info("Camera disconnected successfully")
        return self._status

    def get_status(self) -> CameraStatus:
        """Return current status dataclass."""
        status = self._status
        status.fps = round(self._current_fps, 1)
        return status

    def get_frame(self) -> Optional[bytes]:
        """Get latest encoded JPEG bytes."""
        with self._frame_lock:
            return self._jpeg_frame

    def get_raw_frame(self) -> Optional[np.ndarray]:
        """Get latest OpenCV BGR frame copy."""
        with self._frame_lock:
            return self._raw_frame.copy() if self._raw_frame is not None else None

    def get_frame_id(self) -> int:
        """Get current frame ID index."""
        return self._frame_id

    @staticmethod
    def test_connection(url: str) -> dict:
        """Quick connection test for a camera stream URL."""
        url_str = url.strip()
        try:
            source: Union[int, str] = int(url_str) if url_str.isdigit() else url_str
            cap = cv2.VideoCapture(source)
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

            if not cap.isOpened():
                return {"ok": False, "resolution": None, "error": f"Cannot open camera: {url_str}"}

            ret, frame = cap.read()
            if not ret or frame is None:
                cap.release()
                return {"ok": False, "resolution": None, "error": "No frames received"}

            h, w = frame.shape[:2]
            cap.release()
            return {"ok": True, "resolution": {"width": w, "height": h}, "error": None}
        except Exception as e:
            return {"ok": False, "resolution": None, "error": str(e)}

    # ------------------------------------------------------------------
    # Worker Loop: Ultra-Fast Frame Acquisition
    # ------------------------------------------------------------------
    def _reader_loop(self) -> None:
        """
        Background thread continuously reading latest frames.
        Uses buffer-flushing logic to prevent network stream video lag.
        """
        consecutive_errors = 0

        while not self._stop_event.is_set():
            if self._cap is None or not self._cap.isOpened():
                break

            # Read frame
            ret, frame = self._cap.read()

            if not ret or frame is None:
                consecutive_errors += 1
                if consecutive_errors > 30:  # ~1 second of failure
                    logger.warning("Camera read failed repeatedly, attempting reconnect")
                    self._attempt_reconnect()
                    break
                time.sleep(0.03)
                continue

            consecutive_errors = 0

            # Encode to JPEG
            _, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
            jpeg_bytes = buf.tobytes()

            with self._frame_lock:
                self._raw_frame = frame
                self._jpeg_frame = jpeg_bytes
                self._frame_id += 1

            self._update_fps()

            # Small sleep to yield CPU & lock
            time.sleep(0.01)

    def _cleanup_resources(self) -> None:
        """Release OpenCV capture object."""
        if self._cap:
            try:
                self._cap.release()
            except Exception:
                pass
            self._cap = None

    def _update_fps(self) -> None:
        """Calculate FPS."""
        self._frame_count += 1
        elapsed = time.time() - self._fps_start
        if elapsed >= 1.0:
            self._current_fps = self._frame_count / elapsed
            self._frame_count = 0
            self._fps_start = time.time()

    def _attempt_reconnect(self) -> None:
        """Attempt to reconnect to camera on connection drop."""
        url = self._status.url
        camera_type = self._status.camera_type

        if not url or not camera_type:
            return

        self._status.state = CameraState.RECONNECTING
        logger.info(f"Reconnecting to camera stream: {url}")

        self._cleanup_resources()

        for attempt in range(1, self._max_reconnect_attempts + 1):
            if self._stop_event.is_set():
                return

            time.sleep(self._reconnect_delay)

            try:
                source: Union[int, str] = int(url) if (camera_type == CameraType.LOCAL or url.isdigit()) else url
                cap = cv2.VideoCapture(source)
                cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

                if cap.isOpened():
                    ret, frame = cap.read()
                    if ret and frame is not None:
                        self._cap = cap
                        h, w = frame.shape[:2]
                        self._status = CameraStatus(
                            state=CameraState.CONNECTED,
                            url=url,
                            camera_type=camera_type,
                            resolution=(w, h),
                        )
                        logger.info(f"Reconnected successfully on attempt {attempt}")

                        self._reader_thread = threading.Thread(
                            target=self._reader_loop, daemon=True, name="camera-reader"
                        )
                        self._reader_thread.start()
                        return
                cap.release()
            except Exception as e:
                logger.warning(f"Reconnect attempt {attempt} failed: {e}")

        self._status = CameraStatus(
            state=CameraState.ERROR,
            url=url,
            camera_type=camera_type,
            error="Connection lost and reconnection attempts failed",
        )
        logger.error("Failed to reconnect camera after multiple attempts")
