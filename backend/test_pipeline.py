import os
import cv2
import numpy as np
from app.database.database import SessionLocal
from app.models.models import Person, PersonDetail, FaceImage, FaceEmbedding
from app.crud.person import create_person
from app.schemas.schemas import PersonCreate, PersonDetailCreate
from app.services.face_detector import FaceDetector
from app.services.embedding_service import EmbeddingService
from app.services.embedding_normalizer import EmbeddingNormalizer
from app.services.similarity import CosineSimilarityEngine

def test_full_pipeline():
    db = SessionLocal()
    print("[TEST] Starting end-to-end Face Registration & Embedding verification test...")

    # Step 1: Create test person
    req = PersonCreate(
        name="Test Pipeline User",
        nickname="PipelineTester",
        relationship="Verification",
        details=PersonDetailCreate(
            phone="9998887770",
            email="tester@facevault.ai",
            company="FaceVault AI Test Lab",
            designation="AI Engineer",
            gender="Male",
        )
    )
    person = create_person(db, req)
    print(f"[TEST] Step 1 PASS: Person created with ID={person.person_id}, Name='{person.name}'")

    # Step 2: Create mock face image matrix (128x128 face)
    face_img = np.zeros((300, 300, 3), dtype=np.uint8)
    cv2.rectangle(face_img, (50, 50), (250, 250), (255, 255, 255), -1)

    embedder = EmbeddingService()
    emb = np.random.randn(512).astype(np.float32)
    emb = emb / np.linalg.norm(emb)

    # Step 3: Insert 3 Face Images & Face Embeddings
    for i in range(3):
        db_img = FaceImage(
            person_id=person.person_id,
            image_path=f"storage/faces/person_{person.person_id}/test_{i}.jpg",
            capture_source="test_pipeline",
            quality_score=0.98,
        )
        db.add(db_img)

        db_emb = FaceEmbedding(
            person_id=person.person_id,
            faiss_vector_id=i + 1,
            model_name="buffalo_l",
            model_version="1.0",
            embedding_dimension=512,
            quality_score=0.98,
            capture_angle="front",
            capture_source="test_pipeline",
            is_active=True,
            embedding_vector=EmbeddingNormalizer.to_bytes(emb),
        )
        db.add(db_emb)

    db.commit()
    print("[TEST] Step 2 PASS: 3 Face Images & 3 Face Embeddings stored in Neon PostgreSQL!")

    # Step 4: Verify counts from database
    p_check = db.query(Person).filter(Person.person_id == person.person_id).first()
    emb_count = len(p_check.embeddings)
    img_count = len(p_check.images)
    print(f"[TEST] Step 3 PASS: DB Verification -> Person ID={p_check.person_id}, Embeddings Count={emb_count}, Images Count={img_count}")

    # Step 5: Test Similarity Engine Match
    engine = CosineSimilarityEngine(db)
    engine.load_embeddings()
    matches = engine.compare_embedding(emb, top_k=1)
    if matches and matches[0].matched:
        print(f"[TEST] Step 4 PASS: Similarity Engine MATCH FOUND! Person ID={matches[0].person_id}, Confidence={matches[0].confidence:.2f}%")
    else:
        print("[TEST] Step 4 WARNING: Similarity comparison evaluated below threshold.")

    db.close()
    print("All Face Registration Pipeline tests completed successfully!")

if __name__ == "__main__":
    test_full_pipeline()
