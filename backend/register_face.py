import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

import cv2
from app.database.database import SessionLocal
from app.services import RecognitionService

def register():
    db = SessionLocal()
    svc = RecognitionService(db)
    
    # Apni photo ka path
    img_path = "chico.jpg"
    image = cv2.imread(img_path)
    
    if image is None:
        print("Photo nahi mili!")
        return
    
    # Person ID jo Step 1 mein mila
    person_id = 3  # <-- YEH UPDATE KARO
    
    try:
        emb = svc.register_face(
            person_id=person_id,
            face_image=image,
            capture_source="manual_registration",
            capture_angle="front"
        )
        print(f"✅ Face registered! embedding_id={emb.embedding_id}")
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    register()