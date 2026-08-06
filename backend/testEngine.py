import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"  # Windows pe ONNX error fix

import cv2
import numpy as np
from app.database.database import SessionLocal
from app.services import RecognitionService

def test():
    # DB session
    db = SessionLocal()
    
    # Service initialize (pehli baar model download hoga)
    print("🔄 Initializing Face Recognition Engine...")
    print("   (First run downloads ~300MB model, wait...)")
    svc = RecognitionService(db)
    print("✅ Engine Ready!\n")
    
    # Test image load karo — apni koi photo yahan daalo
    # Ya koi image download kar lo: https://via.placeholder.com/500
    img_path = "chico.jpg"  # <-- YAHAN APNI PHOTO KA PATH DAALO
    
    image = cv2.imread(img_path)
    if image is None:
        print(f"❌ Image not found: {img_path}")
        print("   Koi real photo 'backend/test_photo.jpg' mein daalo")
        return
    
    print(f"🖼️  Image loaded: {image.shape}")
    
    # Recognition run karo
    print("🔍 Running recognition...\n")
    result = svc.recognize(image, camera_source="test_camera")
    
    # Results print karo
    print("=" * 50)
    print(f"⏱️  Processing Time: {result.processing_time_ms}ms")
    print(f"👥 Total Faces: {result.total_faces}")
    print("=" * 50)
    
    if result.recognized_faces:
        print("\n✅ RECOGNIZED FACES:")
        for face in result.recognized_faces:
            print(f"   🧑 {face.person_name} (ID: {face.person_id})")
            print(f"      Confidence: {face.confidence}%")
            print(f"      Similarity: {face.similarity}")
            print(f"      Box: {face.bounding_box}")
    else:
        print("\n❓ No known faces matched")
    
    if result.unknown_faces:
        print(f"\n❓ UNKNOWN FACES: {len(result.unknown_faces)}")
        for face in result.unknown_faces:
            print(f"   Detection Confidence: {face.confidence}%")
            if face.saved_path:
                print(f"   Saved: {face.saved_path}")
    
    db.close()
    print("\n✅ Test Complete!")

if __name__ == "__main__":
    test()