import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    PROJECT_NAME: str = "FaceVault AI Backend"
    API_V1_STR: str = "/api/v1"
    
    # Database
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "postgresql://facevault_admin:facevault_password@localhost:5432/facevault_db",
    )
    
    # Storage
    STORAGE_DIR: str = os.getenv("STORAGE_DIR", "storage")
    FACE_IMAGES_DIR: str = os.path.join(STORAGE_DIR, "persons")
    
    # FAISS Vector Search
    FAISS_INDEX_PATH: str = os.getenv("FAISS_INDEX_PATH", os.path.join(STORAGE_DIR, "faiss.index"))
    
    # Recognition Thresholds
    SIMILARITY_THRESHOLD: float = float(os.getenv("SIMILARITY_THRESHOLD", "0.45"))
    QUALITY_THRESHOLD: float = float(os.getenv("QUALITY_THRESHOLD", "0.20"))
    
    # CORS
    CORS_ORIGINS: list = [
        origin.strip()
        for origin in os.getenv("CORS_ORIGINS", "*").split(",")
        if origin.strip()
    ]

settings = Settings()
