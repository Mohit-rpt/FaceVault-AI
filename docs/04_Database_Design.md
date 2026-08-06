# FaceVault AI - Database Design v1.0

## Overview

FaceVault AI uses a hybrid architecture.

- PostgreSQL stores structured information.
- FAISS stores facial embeddings (vectors).
- Images are stored in the file system (future: cloud storage).

```
Camera
   │
   ▼
Face Detection
   │
   ▼
Embedding Generation
   │
   ▼
FAISS
   │
   ▼
person_id
   │
   ▼
PostgreSQL
```

---

# Tables

## 1. persons

### Purpose

Stores the identity of every registered person.

### Primary Key

person_id

### Relationships

- One → One → person_details
- One → Many → face_embeddings
- One → Many → face_images
- One → Many → interaction_timeline
- One → Many → recognition_logs

### Columns

- person_id
- name
- nickname
- relationship
- created_at
- updated_at

---

## 2. person_details

### Purpose

Stores additional information about a person.

### Relationship

Belongs to exactly one person.

### Columns

- details_id
- person_id
- phone
- email
- college
- company
- designation
- address
- city
- state
- country
- birthday
- remarks
- created_at
- updated_at

---

## 3. face_embeddings

### Purpose

Stores metadata about facial embeddings.

The embedding vectors themselves are NOT stored here.

Vectors are stored in FAISS.

### Relationship

Many embeddings can belong to one person.

### Columns

- embedding_id
- person_id
- faiss_vector_id
- model_name
- model_version
- embedding_dimension
- quality_score
- capture_angle
- capture_source
- is_active
- created_at

---

# Future Tables

- face_images
- interaction_timeline
- recognition_logs
- custom_fields
- settings

---

# Design Rules

1. Images are never stored inside PostgreSQL.
2. Embedding vectors are never stored inside PostgreSQL.
3. PostgreSQL stores only metadata.
4. FAISS stores vector embeddings.
5. Every table references person_id.
6. ON DELETE CASCADE is used where appropriate.
7. Once a table is approved, its design is considered locked unless a major architectural issue is found.

---

# Technology Stack

Database:
- PostgreSQL 17

Vector Database:
- FAISS

Recognition Model:
- InsightFace

Backend:
- FastAPI

Mobile:
- Flutter

Web Dashboard:
- React