FaceVault AI — Master Project Context
Project Name

FaceVault AI

Project Type

Personal AI-powered face recognition and memory system.

Purpose

This project is only for personal use (single admin account).

The system will allow the owner to:

Register people
Store detailed information
Recognize faces using camera
Search people
Maintain interaction history
Retrieve details anytime from phone or laptop
Later support CCTV cameras
Core Vision

FaceVault AI is not just face recognition.

The goal:

Face
 ↓
Identity
 ↓
Information
 ↓
Memory
 ↓
AI Search

Example:

Camera detects a person:

Face Match: 97%

Person:
Rahul Sharma

Company:
Google

Last Interaction:
Hackathon discussion

Tags:
AI, College Friend
User System

Current decision:

Only ONE admin user
No public users
Protected system

Login:

Mobile:

Fingerprint / Biometrics
Password fallback

Laptop:

Password login
AI Recognition Architecture
Face Recognition Model

Selected:

InsightFace

Reason:

High accuracy
Multiple embeddings support
Production quality
Embedding Strategy

Selected:

Multiple embeddings per person.

Example:

Person:

Rahul

Stored embeddings:

Front face
Left face
Right face
Slight angle
Different lighting

Purpose:

Improve recognition accuracy.

Recognition Flow
Camera
 |
 |
Face Detection
 |
 |
InsightFace
 |
 |
Generate Face Embedding
 |
 |
FAISS Vector Search
 |
 |
Find Matching ID
 |
 |
PostgreSQL Lookup
 |
 |
Show Person Details
Technology Stack
Database

PostgreSQL 17

Running through:

Docker

Database:

facevault_db

User:

facevault_admin
Database GUI

pgAdmin 4

Backend

FastAPI (Python)

Architecture:

backend/

app/

├── api/
├── core/
├── database/
├── models/
├── schemas/
├── services/
├── utils/
└── main.py
AI Engine

Planned:

InsightFace
FAISS
OpenCV
Mobile

Planned:

Flutter

Features:

Camera recognition
Registration
Search
History
Web Dashboard

Planned:

React

Purpose:

Laptop management interface.

Database Status

Database V1 is created.

Tables:

1. persons

Main identity table.

Stores:

person_id
name
nickname
relationship
created_at
updated_at
2. person_details

Additional information.

Stores:

phone
email
college
company
designation
address
birthday
remarks

Relationship:

persons 1 ---- 1 person_details
3. face_embeddings

Stores embedding metadata.

Important:

Actual vectors are stored in FAISS, not PostgreSQL.

Stores:

embedding_id
person_id
faiss_vector_id
model_name
model_version
embedding_dimension
quality_score
capture_angle
capture_source
is_active
created_at

Relationship:

persons 1 ---- many face_embeddings
4. face_images

Stores image metadata.

Stores:

image_id
person_id
image_path
capture_source
quality_score
image_hash
created_at

Relationship:

persons 1 ---- many face_images
5. interaction_timeline

Personal memory/history.

Stores:

timeline_id
person_id
interaction_date
title
description
location
tags
created_at

Example:

Met at AI Hackathon
Discussed ML project
6. recognition_logs

Stores every recognition event.

Stores:

log_id
person_id
confidence_score
camera_source
recognition_time_ms
recognized_at
7. custom_fields

Flexible additional information.

Stores:

field_id
person_id
field_name
field_value
created_at
8. settings

Application settings.

Stores:

setting_id
setting_key
setting_value
updated_at
9. face_sessions

Groups recognition sessions.

Stores:

session_id
session_name
camera_source
started_at
ended_at
notes
Database Relationship
                 persons
                    |
     --------------------------------
     |          |          |         |
     |          |          |         |
person_details face_images embeddings timeline

                    |
                    |
             recognition_logs


custom_fields


settings (independent)

face_sessions
       |
       |
recognition_logs
Completed Work
Phase 0

✅ Planning
✅ Requirements
✅ Architecture

Phase 1

✅ Docker setup
✅ PostgreSQL 17
✅ pgAdmin connection

Phase 2

Database:

✅ persons
✅ person_details
✅ face_embeddings
✅ face_images
✅ interaction_timeline
✅ recognition_logs
✅ custom_fields
✅ settings
✅ face_sessions

Phase 3 Current Position

Backend started.

Completed:

✅ FastAPI setup
✅ PostgreSQL connection using SQLAlchemy

Current task:

Create SQLAlchemy models.

Completed:

Person model pending verification
Current Folder
FaceVault-AI/

backend/

app/

database/
    database.py

models/
    person.py

main.py
Next Tasks

Follow this order:

Backend
Complete SQLAlchemy models

Models:

Person
PersonDetails
FaceEmbedding
FaceImage
Timeline
RecognitionLog
Settings
FaceSession
Create Pydantic schemas

Example:

PersonCreate
PersonResponse
Create API endpoints

First:

POST /persons
GET /persons
GET /persons/{id}
Add InsightFace service
services/

face_service.py
Add FAISS integration
ai-engine/

faiss_index
embedding_manager
Create registration pipeline

Flow:

Upload Image

↓

Detect Face

↓

Generate Embedding

↓

Store Image

↓

Store Metadata

↓

Add Vector to FAISS
Development Rules

Important:

Do not redesign database without reason.
Keep changes documented.
Build step-by-step.
Test every module before moving forward.
This is a personal system, not a public SaaS.
Prefer clean architecture over fast coding.
Current Next Action

Continue from:

Create SQLAlchemy models for all database tables.