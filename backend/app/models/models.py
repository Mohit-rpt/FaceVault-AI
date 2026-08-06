from __future__ import annotations

from datetime import datetime, date
from typing import Optional, List

from sqlalchemy import (
    String,
    Integer,
    Float,
    Boolean,
    Text,
    DateTime,
    Date,
    ForeignKey,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship as orm_relationship

from app.database.database import Base
from sqlalchemy import LargeBinary

class Person(Base):
    __tablename__ = "persons"

    person_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    nickname: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    relationship: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    created_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True, server_default=func.now()
    )
    updated_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True, server_default=func.now(), onupdate=func.now()
    )

    details: Mapped[Optional["PersonDetail"]] = orm_relationship(
        back_populates="person", uselist=False, cascade="all, delete-orphan"
    )
    embeddings: Mapped[List["FaceEmbedding"]] = orm_relationship(
        back_populates="person", cascade="all, delete-orphan"
    )
    images: Mapped[List["FaceImage"]] = orm_relationship(
        back_populates="person", cascade="all, delete-orphan"
    )
    timelines: Mapped[List["InteractionTimeline"]] = orm_relationship(
        back_populates="person", cascade="all, delete-orphan"
    )
    recognition_logs: Mapped[List["RecognitionLog"]] = orm_relationship(
        back_populates="person", cascade="all, delete-orphan"
    )
    custom_fields: Mapped[List["CustomField"]] = orm_relationship(
        back_populates="person", cascade="all, delete-orphan"
    )


class PersonDetail(Base):
    __tablename__ = "person_details"

    details_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    person_id: Mapped[int] = mapped_column(
        ForeignKey("persons.person_id", ondelete="CASCADE"), nullable=False
    )
    gender: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    department: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    employee_id: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    phone: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    email: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    college: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    company: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    designation: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    address: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    city: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    state: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    country: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    birthday: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    remarks: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True, server_default=func.now()
    )
    updated_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True, server_default=func.now(), onupdate=func.now()
    )

    person: Mapped["Person"] = orm_relationship(back_populates="details")


class FaceEmbedding(Base):
    __tablename__ = "face_embeddings"
    
    embedding_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    person_id: Mapped[int] = mapped_column(
        ForeignKey("persons.person_id", ondelete="CASCADE"), nullable=False
    )
    
    faiss_vector_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True, default=0)
    model_name: Mapped[str] = mapped_column(String(100), nullable=False)
    model_version: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    embedding_dimension: Mapped[int] = mapped_column(Integer, nullable=False)
    quality_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    capture_angle: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    capture_source: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    is_active: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    created_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True, server_default=func.now()
    )
    embedding_vector: Mapped[Optional[bytes]] = mapped_column(LargeBinary, nullable=True)

    person: Mapped["Person"] = orm_relationship(back_populates="embeddings")


class FaceImage(Base):
    __tablename__ = "face_images"

    image_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    person_id: Mapped[int] = mapped_column(
        ForeignKey("persons.person_id", ondelete="CASCADE"), nullable=False
    )
    image_path: Mapped[str] = mapped_column(Text, nullable=False)
    capture_source: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    quality_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    image_hash: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    created_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True, server_default=func.now()
    )

    person: Mapped["Person"] = orm_relationship(back_populates="images")


class InteractionTimeline(Base):
    __tablename__ = "interaction_timeline"

    timeline_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    person_id: Mapped[int] = mapped_column(
        ForeignKey("persons.person_id", ondelete="CASCADE"), nullable=False
    )
    interaction_date: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    title: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    location: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    tags: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    created_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True, server_default=func.now()
    )

    person: Mapped["Person"] = orm_relationship(back_populates="timelines")


class RecognitionLog(Base):
    __tablename__ = "recognition_logs"

    log_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    person_id: Mapped[int] = mapped_column(
        ForeignKey("persons.person_id", ondelete="CASCADE"), nullable=False
    )
    confidence_score: Mapped[float] = mapped_column(Float, nullable=False)
    camera_source: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    recognition_time_ms: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    recognized_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True, server_default=func.now()
    )

    person: Mapped["Person"] = orm_relationship(back_populates="recognition_logs")


class CustomField(Base):
    __tablename__ = "custom_fields"

    field_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    person_id: Mapped[int] = mapped_column(
        ForeignKey("persons.person_id", ondelete="CASCADE"), nullable=False
    )
    field_name: Mapped[str] = mapped_column(String(100), nullable=False)
    field_value: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True, server_default=func.now()
    )

    person: Mapped["Person"] = orm_relationship(back_populates="custom_fields")


class Setting(Base):
    __tablename__ = "settings"

    setting_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    setting_key: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    setting_value: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    updated_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True, server_default=func.now(), onupdate=func.now()
    )


class FaceSession(Base):
    __tablename__ = "face_sessions"

    session_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    session_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    camera_source: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    started_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True, server_default=func.now()
    )
    ended_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
