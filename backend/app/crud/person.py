from sqlalchemy.orm import Session, joinedload
from sqlalchemy import or_, func
from app import models, schemas
from app.models.models import FaceImage, CustomField, PersonDetail
from typing import Optional

# ==================== Person CRUD ====================
def get_person(db: Session, person_id: int):
    """Single person with all related data loaded"""
    return (
        db.query(models.Person)
        .options(
            joinedload(models.Person.details),
            joinedload(models.Person.embeddings),
            joinedload(models.Person.images),
            joinedload(models.Person.timelines),
            joinedload(models.Person.custom_fields),
        )
        .filter(models.Person.person_id == person_id)
        .first()
    )


def create_person(db: Session, person: schemas.PersonCreate):
    # 1. Create base person
    db_person = models.Person(
        name=person.name,
        nickname=person.nickname,
        relationship=person.relationship,
    )
    db.add(db_person)
    db.commit()
    db.refresh(db_person)

    # 2. Create details if provided
    if person.details:
        db_details = models.PersonDetail(
            person_id=db_person.person_id,
            **person.details.model_dump(exclude_unset=True),
        )
        db.add(db_details)

    # 3. Create custom fields if provided
    if person.custom_fields:
        for field in person.custom_fields:
            db_field = CustomField(
                person_id=db_person.person_id,
                field_name=field.field_name,
                field_value=field.field_value,
            )
            db.add(db_field)

    db.commit()
    return get_person(db, db_person.person_id)


def update_person(db: Session, person_id: int, person_update: schemas.PersonUpdate):
    db_person = get_person(db, person_id)
    if not db_person:
        return None

    update_data = person_update.model_dump(exclude_unset=True)

    # Handle details update
    if "details" in update_data and update_data["details"]:
        details_data = update_data.pop("details")
        if db_person.details:
            for key, value in details_data.items():
                setattr(db_person.details, key, value)
        else:
            db_details = models.PersonDetail(person_id=person_id, **details_data)
            db.add(db_details)

    # Handle custom fields update if explicitly passed
    if "custom_fields" in update_data and update_data["custom_fields"] is not None:
        custom_fields_data = update_data.pop("custom_fields")
        # Clear existing custom fields and replace
        db.query(CustomField).filter(CustomField.person_id == person_id).delete()
        for field_item in custom_fields_data:
            db_field = CustomField(
                person_id=person_id,
                field_name=field_item["field_name"],
                field_value=field_item.get("field_value"),
            )
            db.add(db_field)

    # Update top-level fields
    for key, value in update_data.items():
        setattr(db_person, key, value)

    db.commit()
    return get_person(db, person_id)


def delete_person(db: Session, person_id: int):
    db_person = get_person(db, person_id)
    if db_person:
        db.delete(db_person)
        db.commit()
    return db_person


def get_persons(
    db: Session,
    skip: int = 0,
    limit: int = 100,
    search: Optional[str] = None,
):
    query = db.query(models.Person).outerjoin(models.PersonDetail).outerjoin(models.CustomField)
    
    if search and search.strip():
        term = f"%{search.strip()}%"
        search_filter = or_(
            models.Person.name.ilike(term),
            models.Person.nickname.ilike(term),
            models.Person.relationship.ilike(term),
            PersonDetail.phone.ilike(term),
            PersonDetail.email.ilike(term),
            PersonDetail.company.ilike(term),
            PersonDetail.designation.ilike(term),
            PersonDetail.college.ilike(term),
            PersonDetail.remarks.ilike(term),
            CustomField.field_name.ilike(term),
            CustomField.field_value.ilike(term),
        )
        query = query.filter(search_filter)
    
    query = query.distinct()
    total = query.count()
    items = query.offset(skip).limit(limit).all()
    
    return {
        "items": items,
        "total": total,
        "page": (skip // limit) + 1,
        "pages": (total + limit - 1) // limit if total > 0 else 1,
    }


# ==================== Custom Fields CRUD ====================
def create_custom_field(db: Session, person_id: int, field_name: str, field_value: Optional[str]):
    db_field = CustomField(
        person_id=person_id,
        field_name=field_name,
        field_value=field_value,
    )
    db.add(db_field)
    db.commit()
    db.refresh(db_field)
    return db_field


def get_custom_fields(db: Session, person_id: int):
    return db.query(CustomField).filter(CustomField.person_id == person_id).all()


def delete_custom_field(db: Session, person_id: int, field_id: int):
    db_field = (
        db.query(CustomField)
        .filter(CustomField.field_id == field_id, CustomField.person_id == person_id)
        .first()
    )
    if db_field:
        db.delete(db_field)
        db.commit()
        return True
    return False


def update_custom_field(
    db: Session, person_id: int, field_id: int, field_name: str, field_value: Optional[str]
):
    db_field = (
        db.query(CustomField)
        .filter(CustomField.field_id == field_id, CustomField.person_id == person_id)
        .first()
    )
    if db_field:
        db_field.field_name = field_name
        db_field.field_value = field_value
        db.commit()
        db.refresh(db_field)
        return db_field
    return None


def delete_face_image(db: Session, person_id: int, image_id: int):
    db_image = (
        db.query(FaceImage)
        .filter(FaceImage.image_id == image_id, FaceImage.person_id == person_id)
        .first()
    )
    if db_image:
        # Unlink file from disk if present
        try:
            import os
            if os.path.exists(db_image.image_path):
                os.remove(db_image.image_path)
        except Exception:
            pass

        db.delete(db_image)
        db.commit()
        return True
    return False


# ==================== Timeline CRUD ====================
def create_timeline(db: Session, timeline: schemas.TimelineCreate):
    db_timeline = models.InteractionTimeline(**timeline.model_dump())
    db.add(db_timeline)
    db.commit()
    db.refresh(db_timeline)
    return db_timeline


def get_timelines(db: Session, person_id: int, skip: int = 0, limit: int = 100):
    return (
        db.query(models.InteractionTimeline)
        .filter(models.InteractionTimeline.person_id == person_id)
        .order_by(models.InteractionTimeline.interaction_date.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


# ==================== Recognition Log CRUD ====================
def create_recognition_log(db: Session, log: schemas.RecognitionLogCreate):
    db_log = models.RecognitionLog(**log.model_dump())
    db.add(db_log)
    db.commit()
    db.refresh(db_log)
    return db_log


def get_recognition_logs(db: Session, skip: int = 0, limit: int = 100):
    return (
        db.query(models.RecognitionLog)
        .order_by(models.RecognitionLog.recognized_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


# ==================== Settings CRUD ====================
def get_settings(db: Session):
    return db.query(models.Setting).all()


def update_setting(db: Session, key: str, value: str):
    db_setting = db.query(models.Setting).filter(models.Setting.setting_key == key).first()
    if db_setting:
        db_setting.setting_value = value
    else:
        db_setting = models.Setting(setting_key=key, setting_value=value)
        db.add(db_setting)
    db.commit()
    db.refresh(db_setting)
    return db_setting


# ==================== Face Image CRUD ====================
def create_face_image(
    db: Session,
    person_id: int,
    image_path: str,
    capture_source: Optional[str] = None,
    quality_score: Optional[float] = None,
) -> FaceImage:
    db_image = FaceImage(
        person_id=person_id,
        image_path=image_path,
        capture_source=capture_source,
        quality_score=quality_score,
    )
    db.add(db_image)
    db.commit()
    db.refresh(db_image)
    return db_image