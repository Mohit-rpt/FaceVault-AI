"""
Camera API Router.

Endpoints for connecting, disconnecting, testing, and streaming
external camera feeds (Mobile / CCTV / Local).
"""

import asyncio
import logging
from typing import Optional

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import Response, StreamingResponse
from pydantic import BaseModel, Field

from app.services.camera_manager import CameraManager, CameraType, CameraState
from app.core.response import success_response, error_response

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/camera", tags=["Camera"])

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "*",
    "Access-Control-Allow-Headers": "*",
    "Cache-Control": "no-cache, no-store, must-revalidate",
    "Pragma": "no-cache",
    "Expires": "0",
    "X-Accel-Buffering": "no",
}


# ==================== Request / Response Models ====================


class CameraConnectRequest(BaseModel):
    url: str = Field(..., description="Stream URL (HTTP/RTSP) or webcam index")
    camera_type: str = Field(
        "mobile", description="Camera type: mobile, cctv, or local"
    )


class CameraTestRequest(BaseModel):
    url: str = Field(..., description="Stream URL to test")


# ==================== Helpers ====================


def _serialize_status(s) -> dict:
    """Convert CameraStatus dataclass to JSON-safe dict."""
    return {
        "connected": s.state == CameraState.CONNECTED,
        "state": s.state.value,
        "url": s.url,
        "camera_type": s.camera_type.value if s.camera_type else None,
        "fps": s.fps,
        "resolution": (
            {"width": s.resolution[0], "height": s.resolution[1]}
            if s.resolution
            else None
        ),
        "error": s.error,
    }


def _parse_camera_type(raw: str) -> CameraType:
    """Parse camera type string, default to MOBILE."""
    mapping = {"mobile": CameraType.MOBILE, "cctv": CameraType.CCTV, "local": CameraType.LOCAL}
    return mapping.get(raw.lower(), CameraType.MOBILE)


# ==================== Endpoints ====================


@router.post("/connect", response_model=dict)
def connect_camera(body: CameraConnectRequest):
    """Connect to an external camera stream."""
    url = body.url.strip()
    if not url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Stream URL cannot be empty",
        )

    camera_type = _parse_camera_type(body.camera_type)
    mgr = CameraManager.get_instance()
    result = mgr.connect(url, camera_type)

    if result.state == CameraState.ERROR:
        return error_response(
            message=f"Failed to connect: {result.error}",
            errors={"url": url},
        )

    return success_response(
        data=_serialize_status(result),
        message="Camera connected successfully",
    )


@router.post("/disconnect", response_model=dict)
def disconnect_camera():
    """Disconnect the current camera stream."""
    mgr = CameraManager.get_instance()
    result = mgr.disconnect()
    return success_response(
        data=_serialize_status(result),
        message="Camera disconnected",
    )


@router.get("/status", response_model=dict)
def camera_status():
    """Get current camera connection status."""
    mgr = CameraManager.get_instance()
    result = mgr.get_status()
    return success_response(
        data=_serialize_status(result),
        message="Camera status retrieved",
    )


@router.post("/test", response_model=dict)
def test_camera(body: CameraTestRequest):
    """Quick connection test."""
    url = body.url.strip()
    if not url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Stream URL cannot be empty",
        )

    result = CameraManager.test_connection(url)
    if result["ok"]:
        return success_response(data=result, message="Connection test passed")
    else:
        return success_response(data=result, message=f"Connection test failed: {result['error']}")


@router.get("/frame")
def get_frame():
    """Return the latest single JPEG frame from the connected camera."""
    mgr = CameraManager.get_instance()
    jpeg = mgr.get_frame()

    if jpeg is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No camera connected or no frame available",
        )

    return Response(
        content=jpeg,
        media_type="image/jpeg",
        headers=CORS_HEADERS,
    )


@router.get("/stream")
async def stream_mjpeg():
    """
    MJPEG multipart stream for live preview in <img> tag.
    Properly formatted with Content-Length to prevent browser stream stalls.
    """
    mgr = CameraManager.get_instance()

    if mgr.get_status().state != CameraState.CONNECTED:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No camera connected",
        )

    async def mjpeg_generator():
        last_id = -1
        while True:
            status_obj = mgr.get_status()
            if status_obj.state not in (CameraState.CONNECTED, CameraState.RECONNECTING):
                break

            current_id = mgr.get_frame_id()
            if current_id != last_id:
                jpeg = mgr.get_frame()
                if jpeg is not None:
                    last_id = current_id
                    header = (
                        b"--frame\r\n"
                        b"Content-Type: image/jpeg\r\n"
                        b"Content-Length: " + str(len(jpeg)).encode() + b"\r\n\r\n"
                    )
                    yield header + jpeg + b"\r\n"

            await asyncio.sleep(0.033)

    return StreamingResponse(
        mjpeg_generator(),
        media_type="multipart/x-mixed-replace; boundary=frame",
        headers=CORS_HEADERS,
    )
