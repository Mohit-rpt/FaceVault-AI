"""
Smart Sync Engine Service.

Handles:
- Server sync version tracking
- Bootstrap data export for initial installation
- Delta sync computation (only returning embeddings modified after client version)
- Processing offline recognition log sync batches
"""

import base64
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from app.models.models import Person, FaceEmbedding, FaceImage, PersonDetail, RecognitionLog

logger = logging.getLogger(__name__)


class SyncService:
    """Smart Synchronization Engine service."""

    def __init__(self, db: Session):
        self.db = db

    def get_sync_version(self) -> Dict[str, Any]:
        """
        Get current server max embedding_version and last_updated timestamp.
        """
        max_ver = (
            self.db.query(func.max(FaceEmbedding.embedding_version)).scalar() or 0
        )
        last_updated = (
            self.db.query(func.max(FaceEmbedding.updated_at)).scalar()
            or datetime.utcnow()
        )

        return {
            "embedding_version": max_ver,
            "last_updated": last_updated.isoformat() if isinstance(last_updated, datetime) else str(last_updated),
        }

    def _serialize_embedding(self, emb: FaceEmbedding) -> Dict[str, Any]:
        """Serialize FaceEmbedding ORM instance to dict with base64 encoded vector."""
        vector_b64 = None
        if emb.embedding_vector:
            vector_b64 = base64.b64encode(emb.embedding_vector).decode("utf-8")

        return {
            "embedding_id": emb.embedding_id,
            "person_id": emb.person_id,
            "faiss_vector_id": emb.faiss_vector_id,
            "model_name": emb.model_name,
            "model_version": emb.model_version,
            "embedding_dimension": emb.embedding_dimension,
            "quality_score": emb.quality_score,
            "capture_angle": emb.capture_angle,
            "capture_source": emb.capture_source,
            "is_active": emb.is_active,
            "embedding_version": emb.embedding_version,
            "is_deleted": emb.is_deleted,
            "created_at": emb.created_at.isoformat() if emb.created_at else None,
            "updated_at": emb.updated_at.isoformat() if emb.updated_at else None,
            "embedding_vector_b64": vector_b64,
        }

    def _serialize_person(self, person: Person) -> Dict[str, Any]:
        """Serialize Person ORM instance with details and image metadata."""
        details_dict = None
        if person.details:
            details_dict = {
                "details_id": person.details.details_id,
                "gender": person.details.gender,
                "department": person.details.department,
                "employee_id": person.details.employee_id,
                "phone": person.details.phone,
                "email": person.details.email,
                "college": person.details.college,
                "company": person.details.company,
                "designation": person.details.designation,
                "address": person.details.address,
                "birthday": person.details.birthday.isoformat() if person.details.birthday else None,
            }

        images_list = [
            {
                "image_id": img.image_id,
                "image_path": img.image_path,
                "capture_source": img.capture_source,
                "quality_score": img.quality_score,
            }
            for img in person.images
        ]

        return {
            "person_id": person.person_id,
            "name": person.name,
            "nickname": person.nickname,
            "relationship": person.relationship,
            "is_deleted": person.is_deleted,
            "created_at": person.created_at.isoformat() if person.created_at else None,
            "updated_at": person.updated_at.isoformat() if person.updated_at else None,
            "details": details_dict,
            "images": images_list,
        }

    def get_bootstrap_data(self) -> Dict[str, Any]:
        """
        Export complete active dataset for first installation bootstrap.
        """
        persons = (
            self.db.query(Person)
            .options(joinedload(Person.details), joinedload(Person.images))
            .filter(Person.is_deleted == False)
            .all()
        )

        embeddings = (
            self.db.query(FaceEmbedding)
            .filter(FaceEmbedding.is_deleted == False)
            .all()
        )

        version_info = self.get_sync_version()

        return {
            "version": version_info["embedding_version"],
            "last_updated": version_info["last_updated"],
            "total_persons": len(persons),
            "total_embeddings": len(embeddings),
            "persons": [self._serialize_person(p) for p in persons],
            "embeddings": [self._serialize_embedding(e) for e in embeddings],
        }

    def get_delta_data(self, client_version: int) -> Dict[str, Any]:
        """
        Return ONLY embeddings & persons modified after client_version.
        """
        version_info = self.get_sync_version()
        server_version = version_info["embedding_version"]

        if client_version >= server_version:
            return {
                "status": "up_to_date",
                "version": server_version,
                "last_updated": version_info["last_updated"],
                "changed_embeddings": [],
                "deleted_embedding_ids": [],
                "changed_persons": [],
            }

        # Query modified embeddings
        modified_embeddings = (
            self.db.query(FaceEmbedding)
            .filter(FaceEmbedding.embedding_version > client_version)
            .all()
        )

        changed_embeddings = [
            self._serialize_embedding(e)
            for e in modified_embeddings
            if not e.is_deleted
        ]
        deleted_ids = [
            e.embedding_id for e in modified_embeddings if e.is_deleted
        ]

        # Query modified persons
        person_ids = {e.person_id for e in modified_embeddings}
        modified_persons = []
        if person_ids:
            persons = (
                self.db.query(Person)
                .options(joinedload(Person.details), joinedload(Person.images))
                .filter(Person.person_id.in_(person_ids))
                .all()
            )
            modified_persons = [self._serialize_person(p) for p in persons]

        return {
            "status": "delta_available",
            "version": server_version,
            "last_updated": version_info["last_updated"],
            "changed_embeddings": changed_embeddings,
            "deleted_embedding_ids": deleted_ids,
            "changed_persons": modified_persons,
        }

    def process_offline_logs(self, logs: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Batch insert offline recognition logs from mobile/edge clients.
        """
        inserted_count = 0
        errors = []

        for item in logs:
            try:
                person_id = item.get("person_id")
                confidence = float(item.get("confidence_score", 0.0))
                camera_src = item.get("camera_source", "Offline_Sync")
                rec_time = item.get("recognition_time_ms")
                recognized_at_str = item.get("recognized_at")

                recognized_at = datetime.utcnow()
                if recognized_at_str:
                    try:
                        recognized_at = datetime.fromisoformat(recognized_at_str)
                    except Exception:
                        pass

                if person_id:
                    p_exists = self.db.query(Person.person_id).filter(Person.person_id == person_id).first()
                    if not p_exists:
                        continue

                log_entry = RecognitionLog(
                    person_id=person_id or 0,
                    confidence_score=confidence,
                    camera_source=camera_src,
                    recognition_time_ms=rec_time,
                    recognized_at=recognized_at,
                )
                self.db.add(log_entry)
                inserted_count += 1
            except Exception as e:
                logger.warning(f"Error processing offline log item: {e}")
                errors.append(str(e))

        try:
            self.db.commit()
        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed committing offline logs: {e}")
            return {"success": False, "inserted": 0, "error": str(e)}

        return {
            "success": True,
            "inserted": inserted_count,
            "errors": errors,
        }
