from __future__ import annotations

from datetime import datetime, date
from typing import Optional, List

from pydantic import BaseModel, ConfigDict


# ==================== Person Details ====================
class PersonDetailBase(BaseModel):
    gender: Optional[str] = None
    department: Optional[str] = None
    employee_id: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    college: Optional[str] = None
    company: Optional[str] = None
    designation: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    country: Optional[str] = None
    birthday: Optional[date] = None
    remarks: Optional[str] = None


class PersonDetailCreate(PersonDetailBase):
    pass


class PersonDetailResponse(PersonDetailBase):
    details_id: int
    person_id: int
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)


# ==================== Face Embeddings ====================
class FaceEmbeddingBase(BaseModel):
    faiss_vector_id: Optional[int] = 0
    model_name: str
    model_version: Optional[str] = None
    embedding_dimension: int
    quality_score: Optional[float] = None
    capture_angle: Optional[str] = None
    capture_source: Optional[str] = None
    is_active: Optional[bool] = True


class FaceEmbeddingCreate(FaceEmbeddingBase):
    person_id: int


class FaceEmbeddingResponse(FaceEmbeddingBase):
    embedding_id: int
    person_id: int
    created_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)


# ==================== Face Images ====================
class FaceImageBase(BaseModel):
    image_path: str
    capture_source: Optional[str] = None
    quality_score: Optional[float] = None
    image_hash: Optional[str] = None


class FaceImageCreate(FaceImageBase):
    person_id: int


class FaceImageResponse(FaceImageBase):
    image_id: int
    person_id: int
    created_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)


# ==================== Interaction Timeline ====================
class TimelineBase(BaseModel):
    interaction_date: datetime
    title: str
    description: Optional[str] = None
    location: Optional[str] = None
    tags: Optional[str] = None


class TimelineCreate(TimelineBase):
    person_id: int


class TimelineResponse(TimelineBase):
    timeline_id: int
    person_id: int
    created_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)


# ==================== Recognition Logs ====================
class RecognitionLogBase(BaseModel):
    confidence_score: float
    camera_source: Optional[str] = None
    recognition_time_ms: Optional[int] = None


class RecognitionLogCreate(RecognitionLogBase):
    person_id: int


class RecognitionLogResponse(RecognitionLogBase):
    log_id: int
    person_id: int
    recognized_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)


# ==================== Custom Fields ====================
class CustomFieldBase(BaseModel):
    field_name: str
    field_value: Optional[str] = None


class CustomFieldCreate(CustomFieldBase):
    person_id: Optional[int] = None


class CustomFieldResponse(CustomFieldBase):
    field_id: int
    person_id: int
    created_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)


# ==================== Settings ====================
class SettingBase(BaseModel):
    setting_key: str
    setting_value: Optional[str] = None


class SettingCreate(SettingBase):
    pass


class SettingResponse(SettingBase):
    setting_id: int
    updated_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)


# ==================== Face Sessions ====================
class FaceSessionBase(BaseModel):
    session_name: Optional[str] = None
    camera_source: Optional[str] = None
    ended_at: Optional[datetime] = None
    notes: Optional[str] = None


class FaceSessionCreate(FaceSessionBase):
    pass


class FaceSessionResponse(FaceSessionBase):
    session_id: int
    started_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)


# ==================== Person (Main) ====================
class PersonBase(BaseModel):
    name: str
    nickname: Optional[str] = None
    relationship: Optional[str] = None


class PersonCreate(PersonBase):
    details: Optional[PersonDetailCreate] = None
    custom_fields: Optional[List[CustomFieldBase]] = []


class PersonUpdate(BaseModel):
    name: Optional[str] = None
    nickname: Optional[str] = None
    relationship: Optional[str] = None
    details: Optional[PersonDetailCreate] = None
    custom_fields: Optional[List[CustomFieldBase]] = None


class PersonResponse(PersonBase):
    person_id: int
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    details: Optional[PersonDetailResponse] = None
    embeddings: List[FaceEmbeddingResponse] = []
    images: List[FaceImageResponse] = []
    timelines: List[TimelineResponse] = []
    custom_fields: List[CustomFieldResponse] = []
    model_config = ConfigDict(from_attributes=True)


# ==================== Face Registration ====================
class FaceRegistrationResponse(BaseModel):
    person_id: int
    registered_images: int
    failed_images: int
    embeddings_created: int
    average_quality: float
    details: List[dict] = []
    model_config = ConfigDict(from_attributes=True)


# ==================== Recognition & Search API ====================
class RecognizedFaceResponse(BaseModel):
    person_id: int
    person_name: str
    confidence: float
    similarity: float
    bounding_box: List[float]


class UnknownFaceResponse(BaseModel):
    confidence: float
    bounding_box: List[float]


class RecognitionAPIResponse(BaseModel):
    success: bool
    processing_time_ms: int
    faces_detected: int
    recognized_faces: List[RecognizedFaceResponse]
    unknown_faces: List[UnknownFaceResponse]
    model_config = ConfigDict(from_attributes=True)


class FaceSearchMatchResponse(BaseModel):
    person: PersonResponse
    confidence: float
    similarity: float


# ==================== Standard API Response ====================
class StandardResponse(BaseModel):
    success: bool
    message: str
    data: Optional[dict] = None
    errors: Optional[dict] = None
    model_config = ConfigDict(from_attributes=True)


class PersonItem(BaseModel):
    person_id: int
    name: str
    nickname: Optional[str] = None
    relationship: Optional[str] = None


class PersonListData(BaseModel):
    items: List[PersonItem]
    total: int
    page: int
    pages: int


class PersonListResponse(BaseModel):
    success: bool
    message: str
    data: PersonListData