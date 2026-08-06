import logging
import os
import gc
import shutil
from datetime import datetime
from pathlib import Path
from typing import List, Optional

import cv2
import numpy as np
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Query
from sqlalchemy.orm import Session
from fastapi.responses import JSONResponse

from app.database.database import get_db
from app import schemas, crud, models
from app.services import (
    RecognitionService,
    ImageValidator,
    ImageQualityAssessor,
    FaceDetector,
    EmbeddingService,
    EmbeddingNormalizer,
    FaceAlignment,
)
from app.core.response import success_response, error_response
from app.core.exceptions import NotFoundException
from app.core.utils import get_image_url
from app.services.face_detector_instance import get_face_detector

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/persons", tags=["Persons"])


# ==================== Person CRUD ====================

@router.post(
    "", response_model=schemas.StandardResponse, status_code=status.HTTP_201_CREATED
)
def create_person(person: schemas.PersonCreate, db: Session = Depends(get_db)):
    db_person = crud.create_person(db=db, person=person)
    return JSONResponse(
        status_code=201,
        content=success_response(
            data={
                "person_id": db_person.person_id,
                "name": db_person.name,
                "nickname": db_person.nickname,
                "relationship": db_person.relationship,
                "created_at": db_person.created_at.isoformat() if db_person.created_at else None,
            },
            message="Person profile created successfully",
        )
    )


@router.get("")
def read_persons(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    result = crud.get_persons(db, skip=skip, limit=limit, search=search)

    items = []
    for person in result["items"]:
        items.append(
            {
                "person_id": person.person_id,
                "name": person.name,
                "nickname": person.nickname,
                "relationship": person.relationship,
                "created_at": person.created_at.isoformat() if person.created_at else None,
                "updated_at": person.updated_at.isoformat() if person.updated_at else None,
                "embeddings_count": len(person.embeddings) if person.embeddings else 0,
                "images_count": len(person.images) if person.images else 0,
                "company": person.details.company if person.details else None,
                "phone": person.details.phone if person.details else None,
                "email": person.details.email if person.details else None,
            }
        )

    return JSONResponse(
        content=success_response(
            data={
                "items": items,
                "total": result["total"],
                "page": result["page"],
                "pages": result["pages"],
            },
            message="Persons retrieved successfully",
        )
    )


@router.get("/{person_id}")
def read_person(person_id: int, db: Session = Depends(get_db)):
    db_person = crud.get_person(db, person_id=person_id)
    if db_person is None:
        return JSONResponse(
            status_code=404, content=error_response(message="Person not found")
        )

    details_dict = None
    if db_person.details:
        d = db_person.details
        details_dict = {
            "details_id": d.details_id,
            "person_id": d.person_id,
            "gender": getattr(d, 'gender', None),
            "department": getattr(d, 'department', None),
            "employee_id": getattr(d, 'employee_id', None),
            "phone": d.phone,
            "email": d.email,
            "college": d.college,
            "company": d.company,
            "designation": d.designation,
            "address": d.address,
            "city": d.city,
            "state": d.state,
            "country": d.country,
            "birthday": d.birthday.isoformat() if d.birthday else None,
            "remarks": d.remarks,
        }

    custom_fields_list = [
        {
            "field_id": cf.field_id,
            "person_id": cf.person_id,
            "field_name": cf.field_name,
            "field_value": cf.field_value,
        }
        for cf in (db_person.custom_fields or [])
    ]

    images_list = [
        {
            "image_id": img.image_id,
            "person_id": img.person_id,
            "image_path": get_image_url(img.image_path),
            "quality_score": img.quality_score,
            "created_at": img.created_at.isoformat() if img.created_at else None,
        }
        for img in (db_person.images or [])
    ]

    return JSONResponse(
        content=success_response(
            data={
                "person_id": db_person.person_id,
                "name": db_person.name,
                "nickname": db_person.nickname,
                "relationship": db_person.relationship,
                "created_at": db_person.created_at.isoformat() if db_person.created_at else None,
                "updated_at": db_person.updated_at.isoformat() if db_person.updated_at else None,
                "details": details_dict,
                "custom_fields": custom_fields_list,
                "images": images_list,
                "embeddings_count": len(db_person.embeddings) if db_person.embeddings else 0,
            },
            message="Person retrieved successfully",
        )
    )


@router.put("/{person_id}")
def update_person(
    person_id: int, person: schemas.PersonUpdate, db: Session = Depends(get_db)
):
    db_person = crud.update_person(db, person_id=person_id, person_update=person)
    if db_person is None:
        return JSONResponse(
            status_code=404, content=error_response(message="Person not found")
        )
    return JSONResponse(
        content=success_response(
            data={"person_id": db_person.person_id, "name": db_person.name},
            message="Person profile updated successfully",
        )
    )


@router.delete("/{person_id}")
def delete_person(person_id: int, db: Session = Depends(get_db)):
    db_person = crud.delete_person(db, person_id=person_id)
    if db_person is None:
        return JSONResponse(
            status_code=404, content=error_response(message="Person not found")
        )
    return JSONResponse(
        content=success_response(
            data={"person_id": person_id},
            message="Person deleted successfully",
        )
    )


# ==================== Custom Fields APIs ====================

@router.get("/{person_id}/custom-fields")
def get_custom_fields(person_id: int, db: Session = Depends(get_db)):
    fields = crud.get_custom_fields(db, person_id=person_id)
    data = [
        {
            "field_id": f.field_id,
            "person_id": f.person_id,
            "field_name": f.field_name,
            "field_value": f.field_value,
        }
        for f in fields
    ]
    return JSONResponse(content=success_response(data=data, message="Custom fields fetched"))


@router.post("/{person_id}/custom-fields")
def create_custom_field(
    person_id: int, field: schemas.CustomFieldBase, db: Session = Depends(get_db)
):
    db_person = crud.get_person(db, person_id)
    if not db_person:
        return JSONResponse(status_code=404, content=error_response(message="Person not found"))

    new_field = crud.create_custom_field(
        db=db,
        person_id=person_id,
        field_name=field.field_name,
        field_value=field.field_value,
    )
    return JSONResponse(
        status_code=201,
        content=success_response(
            data={
                "field_id": new_field.field_id,
                "person_id": new_field.person_id,
                "field_name": new_field.field_name,
                "field_value": new_field.field_value,
            },
            message="Custom field created",
        ),
    )


@router.put("/{person_id}/custom-fields/{field_id}")
def update_custom_field(
    person_id: int, field_id: int, field: schemas.CustomFieldBase, db: Session = Depends(get_db)
):
    updated = crud.update_custom_field(
        db=db,
        person_id=person_id,
        field_id=field_id,
        field_name=field.field_name,
        field_value=field.field_value,
    )
    if not updated:
        return JSONResponse(status_code=404, content=error_response(message="Custom field not found"))
    return JSONResponse(
        content=success_response(
            data={
                "field_id": updated.field_id,
                "person_id": updated.person_id,
                "field_name": updated.field_name,
                "field_value": updated.field_value,
            },
            message="Custom field updated",
        )
    )


@router.delete("/{person_id}/custom-fields/{field_id}")
def delete_custom_field(person_id: int, field_id: int, db: Session = Depends(get_db)):
    success = crud.delete_custom_field(db, person_id=person_id, field_id=field_id)
    if not success:
        return JSONResponse(status_code=404, content=error_response(message="Custom field not found"))
    return JSONResponse(content=success_response(data={"field_id": field_id}, message="Custom field deleted"))


# ==================== Registered Face Image Delete API ====================

@router.delete("/{person_id}/images/{image_id}")
def delete_registered_face_image(person_id: int, image_id: int, db: Session = Depends(get_db)):
    success = crud.delete_face_image(db, person_id=person_id, image_id=image_id)
    if not success:
        return JSONResponse(status_code=404, content=error_response(message="Face image not found"))
    return JSONResponse(content=success_response(data={"image_id": image_id}, message="Face image removed"))


# ==================== Face Search API ====================

@router.post("/search-by-face")
def search_person_by_face(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    """
    Given a face image, perform face detection & vector embedding comparison to find matching Person profile.
    """
    try:
        contents = file.file.read()
        nparr = np.frombuffer(contents, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if image is None:
            return JSONResponse(status_code=400, content=error_response(message="Invalid image format"))

        recognition_service = RecognitionService()
        result = recognition_service.recognize_faces(db=db, image=image)

        if result.recognized_faces:
            top_match = result.recognized_faces[0]
            matched_person = crud.get_person(db, person_id=top_match.person_id)

            if matched_person:
                return JSONResponse(
                    content=success_response(
                        data={
                            "matched": True,
                            "confidence": round(top_match.confidence * 100, 2),
                            "similarity": round(top_match.similarity, 4),
                            "person": {
                                "person_id": matched_person.person_id,
                                "name": matched_person.name,
                                "nickname": matched_person.nickname,
                                "relationship": matched_person.relationship,
                                "company": matched_person.details.company if matched_person.details else None,
                                "phone": matched_person.details.phone if matched_person.details else None,
                                "email": matched_person.details.email if matched_person.details else None,
                            },
                        },
                        message="Face match found",
                    )
                )

        return JSONResponse(
            content=success_response(
                data={"matched": False, "message": "No registered person matched the uploaded face."},
                message="No face match found",
            )
        )
    except Exception as e:
        logger.error(f"Face search failed: {e}")
        return JSONResponse(status_code=500, content=error_response(message=f"Face search failed: {str(e)}"))
    finally:
        file.file.close()


# ==================== Timeline Routes ====================

@router.post("/{person_id}/timeline", status_code=201)
def create_timeline(
    person_id: int, timeline: schemas.TimelineBase, db: Session = Depends(get_db)
):
    db_person = crud.get_person(db, person_id)
    if not db_person:
        return JSONResponse(status_code=404, content=error_response(message="Person not found"))

    timeline_data = timeline.model_dump()
    timeline_data["person_id"] = person_id
    created = crud.create_timeline(db=db, timeline=schemas.TimelineCreate(**timeline_data))
    return JSONResponse(
        status_code=201,
        content=success_response(
            data={"timeline_id": created.timeline_id, "title": created.title},
            message="Timeline entry created",
        ),
    )


@router.get("/{person_id}/timeline")
def read_timelines(
    person_id: int, skip: int = 0, limit: int = 100, db: Session = Depends(get_db)
):
    timelines = crud.get_timelines(db, person_id=person_id, skip=skip, limit=limit)
    data = [
        {
            "timeline_id": t.timeline_id,
            "person_id": t.person_id,
            "title": t.title,
            "description": t.description,
            "location": t.location,
            "tags": t.tags,
            "interaction_date": t.interaction_date.isoformat() if t.interaction_date else None,
        }
        for t in timelines
    ]
    return JSONResponse(content=success_response(data=data, message="Timelines fetched"))


# ==================== Face Registration API ====================

def _save_uploaded_image(
    upload_file: UploadFile, person_id: int, index: int, storage_dir: str
) -> str:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    ext = Path(upload_file.filename).suffix or ".jpg"
    filename = f"person_{person_id}_{timestamp}_{index}{ext}"

    person_dir = os.path.join(storage_dir, f"person_{person_id}")
    Path(person_dir).mkdir(parents=True, exist_ok=True)

    file_path = os.path.join(person_dir, filename)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(upload_file.file, buffer)

    return file_path


def _save_cropped_face(
    face_image: np.ndarray, person_id: int, index: int, storage_dir: str
) -> str:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    filename = f"person_{person_id}_{timestamp}_{index}_crop.jpg"

    person_dir = os.path.join(storage_dir, f"person_{person_id}")
    Path(person_dir).mkdir(parents=True, exist_ok=True)

    file_path = os.path.join(person_dir, filename)
    cv2.imwrite(file_path, face_image)

    return file_path


@router.post(
    "/{person_id}/register-face",
    response_model=schemas.FaceRegistrationResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_face(
    person_id: int,
    files: Optional[List[UploadFile]] = File(None),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
):
    detector = get_face_detector()
    embedder = EmbeddingService()
    validator = ImageValidator()
    quality_assessor = ImageQualityAssessor()

    uploaded_files = files or ([] if file is None else [file])
    logger.info(f"Request received: register-face for person_id={person_id}, file_count={len(uploaded_files)}")

    # Validate person exists
    person = crud.get_person(db, person_id)
    if not person:
        raise HTTPException(status_code=404, detail="Person not found")

    # Flexible image count validation: 1 to 20 images
    if len(uploaded_files) < 1:
        raise HTTPException(
            status_code=400,
            detail=f"At least 1 image is required for face registration.",
        )
    if len(uploaded_files) > 20:
        raise HTTPException(
            status_code=400,
            detail=f"Maximum 20 images allowed. Got {len(uploaded_files)}.",
        )

    storage_dir = os.getenv("FACE_STORAGE_DIR", "storage/faces")
    Path(storage_dir).mkdir(parents=True, exist_ok=True)

    registered = 0
    failed = 0
    embeddings_created = 0
    quality_scores = []
    details = []

    for idx, upload_file in enumerate(uploaded_files):
        logger.info(f"Filename received: {upload_file.filename}")
        detail = {
            "filename": upload_file.filename,
            "status": "pending",
            "reason": None,
            "quality_score": None,
        }

        try:
            contents = upload_file.file.read()
            nparr = np.frombuffer(contents, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

            if image is None:
                raise ValueError("Could not decode image")
            logger.info(f"Image decoded for filename: {upload_file.filename}")

            validation = validator.validate(image)
            if not validation.valid:
                raise ValueError(f"Image validation failed: {validation.message}")

            logger.info(f"Face detector called for filename: {upload_file.filename}")
            detected_faces = detector.detect(image)

            if len(detected_faces) > 1:
                raise ValueError(
                    f"Multiple faces detected: {len(detected_faces)}. Exactly one face required."
                )
            if len(detected_faces) == 0:
                raise ValueError("No face detected in the image.")

            face = detected_faces[0]

            quality = quality_assessor.assess(face.face_image)
            quality_scores.append(quality.blur_score)

            original_path = _save_uploaded_image(
                upload_file, person_id, idx, storage_dir
            )

            crop_path = _save_cropped_face(face.face_image, person_id, idx, storage_dir)

            if face.embedding is None:
                raise ValueError("No embedding extracted from face")

            emb_result = embedder.get_embedding(face.embedding)
            logger.info(f"Embedding generated for filename: {upload_file.filename}")

            db_image = crud.create_face_image(
                db=db,
                person_id=person_id,
                image_path=original_path,
                capture_source="registration_api",
                quality_score=face.detection_score,
            )

            db_embedding = models.FaceEmbedding(
                person_id=person_id,
                faiss_vector_id=idx + 1,
                model_name="buffalo_sc",
                model_version="1.0",
                embedding_dimension=emb_result.dimension,
                quality_score=face.detection_score,
                capture_angle="front",
                capture_source="registration_api",
                is_active=True,
                embedding_vector=EmbeddingNormalizer.to_bytes(emb_result.embedding),
            )
            db.add(db_embedding)
            db.commit()
            db.refresh(db_embedding)

            registered += 1
            embeddings_created += 1
            detail["status"] = "success"
            detail["quality_score"] = round(face.detection_score, 4)
            detail["embedding_id"] = db_embedding.embedding_id
            detail["image_id"] = db_image.image_id

        except ValueError as ve:
            db.rollback()
            failed += 1
            detail["status"] = "failed"
            detail["reason"] = str(ve)
            logger.warning(f"Image {upload_file.filename} failed: {ve}")

        except Exception as e:
            db.rollback()
            failed += 1
            detail["status"] = "failed"
            detail["reason"] = f"Unexpected error: {str(e)}"
            logger.error(f"Image {upload_file.filename} error: {e}")

        finally:
            upload_file.file.close()
            contents = None
            nparr = None
            image = None
            gc.collect()
            details.append(detail)

    if embeddings_created == 0 or registered == 0:
        reasons = [d.get("reason") for d in details if d.get("reason")]
        raise HTTPException(
            status_code=400,
            detail=f"Face registration failed: No valid embeddings created. Reasons: {reasons}",
        )

    avg_quality = (
        round(sum(quality_scores) / len(quality_scores), 2) if quality_scores else 0.0
    )

    logger.info(f"Response returned for person_id={person_id}: registered={registered}, failed={failed}, embeddings={embeddings_created}")

    return schemas.FaceRegistrationResponse(
        person_id=person_id,
        registered_images=registered,
        failed_images=failed,
        embeddings_created=embeddings_created,
        average_quality=avg_quality,
        details=details,
    )
