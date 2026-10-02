"""
Regression test for FaceVault AI Delta Sync & Monotonic Versioning.

Verifies:
1. Initial state at client_version == server_version returns "up_to_date".
2. Registering a new friend increments server embedding_version monotonically.
3. Delta sync with previous client_version returns "delta_available", the new embedding,
   and the new person record without requiring a bootstrap reset.
4. Cleans up test artifacts after verification.
"""

import numpy as np
from app.database.database import SessionLocal
from app.models.models import Person, FaceEmbedding, FaceImage
from app.services.sync_service import SyncService, get_next_embedding_version
from app.services.embedding_normalizer import EmbeddingNormalizer


def test_delta_sync_after_friend_registration():
    db = SessionLocal()
    print("[TEST] Starting Delta Sync Regression Test...")

    try:
        sync_service = SyncService(db)

        # 1. Capture baseline server version
        baseline_info = sync_service.get_sync_version()
        v0 = baseline_info["embedding_version"]
        print(f"[TEST] 1. Baseline server embedding_version: {v0}")

        # 2. Verify delta sync from current version reports up-to-date
        delta_v0 = sync_service.get_delta_data(client_version=v0)
        assert delta_v0["status"] == "up_to_date", f"Expected up_to_date, got {delta_v0['status']}"
        assert len(delta_v0["changed_embeddings"]) == 0, "Expected 0 changed embeddings"
        assert len(delta_v0["changed_persons"]) == 0, "Expected 0 changed persons"
        print(f"[TEST] 2. Delta sync at client_version={v0} correctly reports 'up_to_date'")

        # 3. Register a new friend (simulating register-face)
        friend = Person(
            name="Regression Test Friend",
            nickname="TestFriend",
            relationship="Friend",
            is_deleted=False,
        )
        db.add(friend)
        db.commit()
        db.refresh(friend)
        print(f"[TEST] 3. Created friend Person(id={friend.person_id}, name='{friend.name}')")

        # Compute next monotonic version using the production helper
        v1 = get_next_embedding_version(db)
        assert v1 > v0, f"Expected monotonic increase: v1 ({v1}) > v0 ({v0})"
        print(f"[TEST] 4. Computed next monotonic version: {v1} (v0 was {v0})")

        # Generate mock 512-dim unit normalized embedding
        np.random.seed(42)
        raw_vec = np.random.randn(512).astype(np.float32)
        norm_vec = raw_vec / np.linalg.norm(raw_vec)
        vec_bytes = EmbeddingNormalizer.to_bytes(norm_vec)

        friend_embedding = FaceEmbedding(
            person_id=friend.person_id,
            faiss_vector_id=1,
            model_name="buffalo_sc",
            model_version="1.0",
            embedding_dimension=512,
            quality_score=0.95,
            capture_angle="front",
            capture_source="registration_api",
            is_active=True,
            embedding_version=v1,
            is_deleted=False,
            embedding_vector=vec_bytes,
        )
        db.add(friend_embedding)
        db.commit()
        db.refresh(friend_embedding)
        print(f"[TEST] 5. Registered embedding_id={friend_embedding.embedding_id} with version={v1}")

        # 4. Verify server version now reflects v1
        new_info = sync_service.get_sync_version()
        assert new_info["embedding_version"] == v1, f"Expected server version {v1}, got {new_info['embedding_version']}"
        print(f"[TEST] 6. Server version correctly updated to {v1}")

        # 5. Execute delta sync as client holding v0 (WITHOUT bootstrap reset)
        delta_result = sync_service.get_delta_data(client_version=v0)
        assert delta_result["status"] == "delta_available", f"Expected delta_available, got {delta_result['status']}"
        assert delta_result["version"] == v1, f"Expected version {v1}, got {delta_result['version']}"

        # Verify embedding presence
        changed_emb_ids = [e["embedding_id"] for e in delta_result["changed_embeddings"]]
        assert friend_embedding.embedding_id in changed_emb_ids, f"Friend embedding {friend_embedding.embedding_id} not in delta"
        
        # Verify person presence
        changed_p_ids = [p["person_id"] for p in delta_result["changed_persons"]]
        assert friend.person_id in changed_p_ids, f"Friend person_id {friend.person_id} not in delta persons"

        matched_p = next(p for p in delta_result["changed_persons"] if p["person_id"] == friend.person_id)
        assert matched_p["name"] == "Regression Test Friend", "Person name mismatch"

        print(f"[TEST] 7. PASS: Delta sync successfully retrieved friend embedding without bootstrap reset!")
        print(f"         Changed embeddings: {len(delta_result['changed_embeddings'])}, Persons: {len(delta_result['changed_persons'])}")

    finally:
        # Cleanup test records
        try:
            db.query(FaceEmbedding).filter(FaceEmbedding.person_id == friend.person_id).delete()
            db.query(Person).filter(Person.person_id == friend.person_id).delete()
            db.commit()
            print("[TEST] 8. Cleaned up temporary test friend and embeddings.")
        except Exception as e:
            print(f"[TEST] Cleanup warning: {e}")
        finally:
            db.close()

    print("\n[SUCCESS] All Delta Sync Regression Tests PASSED successfully!")


if __name__ == "__main__":
    test_delta_sync_after_friend_registration()
