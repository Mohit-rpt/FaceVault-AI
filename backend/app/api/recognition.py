"""
Recognition API Endpoint.

Production-ready face recognition endpoint.
Supports multiple faces, structured error handling, and async processing.
"""

import logging
import os
from typing import Optional

import cv2
import numpy as np
from fastapi import APIRouter, Depends, File, UploadFile, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.orm import joinedload
from fastapi import APIRouter, Depends, File, UploadFile, HTTPException, status, Query
from app.database.database import get_db
from app import schemas, models
from app.services import (
    RecognitionService,
    ImageValidator,
    ImageQualityAssessor,
    FaceDetector,
    EmbeddingService,
    EmbeddingNormalizer,
    FaceAlignment,
)
from app.core.response import success_response
from app.core.utils import get_image_url
from datetime import datetime, timedelta
from sqlalchemy import func
from app.services.face_detector_instance import get_face_detector

detector = get_face_detector()

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/recognition", tags=["Recognition"])


def get_recognition_service(db: Session = Depends(get_db)) -> RecognitionService:
    """
    Dependency injection for RecognitionService.
    Creates fresh instance per request with all sub-services.
    """
    return RecognitionService(
        db=db,
        detector=detector,
        embedder=EmbeddingService(),
    )


@router.post(
    "",
    response_model=schemas.RecognitionAPIResponse,
    status_code=status.HTTP_200_OK,
    summary="Recognize faces in an image",
    description="""
    Upload an image to recognize faces against registered persons.
    
    - Supports multiple faces in single image
    - Returns recognized persons and unknown faces
    - Saves recognition logs automatically
    - Saves unknown faces to storage
    """,
)
async def recognize_faces(
    image: UploadFile = File(..., description="Image containing face(s) to recognize"),
    camera_source: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """
    Recognize faces in uploaded image.

    Args:
        image: Uploaded image file
        camera_source: Optional camera identifier for logging

    Returns:
        RecognitionAPIResponse with detected faces, recognized persons, and unknown faces
    """
    import time

    start_time = time.time()

    # Validate file type
    allowed_types = {"image/jpeg", "image/png", "image/jpg", "image/webp"}
    if image.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type: {image.content_type}. Allowed: {', '.join(allowed_types)}",
        )

    try:
        # Read image bytes
        contents = await image.read()
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Could not decode image. Ensure valid image format.",
            )

        # Initialize recognition service
        service = RecognitionService(
            db=db,
            detector=None,
            embedder=EmbeddingService(),
        )

        # Run recognition
        result = service.recognize(
            image=img,
            camera_source=camera_source or "api_upload",
            save_unknown=True,
        )

        # Build response
        recognized = [
            schemas.RecognizedFaceResponse(
                person_id=face.person_id,
                person_name=face.person_name,
                confidence=face.confidence,
                similarity=face.similarity,
                bounding_box=face.bounding_box,
            )
            for face in result.recognized_faces
        ]

        unknowns = [
            schemas.UnknownFaceResponse(
                confidence=face.confidence,
                bounding_box=face.bounding_box,
            )
            for face in result.unknown_faces
        ]

        processing_time = result.processing_time_ms or int(
            (time.time() - start_time) * 1000
        )

        return schemas.RecognitionAPIResponse(
            success=True,
            processing_time_ms=processing_time,
            faces_detected=result.total_faces,
            recognized_faces=recognized,
            unknown_faces=unknowns,
        )

    except HTTPException:
        raise

    except Exception as e:
        logger.error(f"Recognition failed: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Recognition processing failed: {str(e)}",
        )


@router.get("/logs", response_model=dict)
def read_logs(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    date: Optional[str] = Query(None, description="today, yesterday, or YYYY-MM-DD"),
    person_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    query = db.query(models.RecognitionLog).options(
        joinedload(models.RecognitionLog.person)
    )

    # Date filtering
    if date == "today":
        today = datetime.now().date()
        query = query.filter(func.date(models.RecognitionLog.recognized_at) == today)
    elif date == "yesterday":
        yesterday = (datetime.now() - timedelta(days=1)).date()
        query = query.filter(
            func.date(models.RecognitionLog.recognized_at) == yesterday
        )
    elif date:
        try:
            filter_date = datetime.strptime(date, "%Y-%m-%d").date()
            query = query.filter(
                func.date(models.RecognitionLog.recognized_at) == filter_date
            )
        except ValueError:
            pass

    # Person filter
    if person_id:
        query = query.filter(models.RecognitionLog.person_id == person_id)

    total = query.count()
    items = (
        query.order_by(models.RecognitionLog.recognized_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

    serialized_items = []
    for item in items:
        serialized_items.append(
            {
                "log_id": item.log_id,
                "person_id": item.person_id,
                "confidence_score": item.confidence_score,
                "camera_source": item.camera_source,
                "recognition_time_ms": item.recognition_time_ms,
                "recognized_at": item.recognized_at.isoformat()
                if item.recognized_at
                else None,
                "person": {
                    "person_id": item.person.person_id,
                    "name": item.person.name,
                    "nickname": item.person.nickname,
                    "relationship": item.person.relationship,
                }
                if item.person
                else None,
            }
        )

    return success_response(
        data={
            "items": serialized_items,
            "total": total,
            "page": (skip // limit) + 1,
            "pages": (total + limit - 1) // limit,
        },
        message="Recognition logs retrieved",
    )
