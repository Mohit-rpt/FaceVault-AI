import os
import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.database.database import engine, Base
from app.api import persons_router, recognition_router, settings_router, camera_router
from app.core.exceptions import FaceVaultException
from app.core.response import error_response
from app.services.face_detector_instance import get_face_detector

logger = logging.getLogger(__name__)

# Auto-create database tables
Base.metadata.create_all(bind=engine)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI Lifespan handler.
    Pre-loads InsightFace Singleton model into RAM at server startup,
    ensuring zero model download or loading delay during HTTP requests.
    """
    logger.info("Starting FaceVault AI Backend...")
    try:
        logger.info("Pre-loading InsightFace Singleton model during startup...")
        get_face_detector()
        logger.info("InsightFace model initialized successfully at startup.")
    except Exception as e:
        logger.error(f"Error initializing InsightFace model at startup: {e}")

    yield

    logger.info("Shutting down FaceVault AI Backend...")


app = FastAPI(
    title="FaceVault AI",
    description="Personal AI-powered Face Recognition & Memory System",
    version="1.0.0",
    lifespan=lifespan,
)

# Spec-compliant CORS Middleware for Flutter Web, React, and Mobile Clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# Register API Routers
app.include_router(persons_router, prefix="/api/v1")
app.include_router(recognition_router, prefix="/api/v1")
app.include_router(settings_router, prefix="/api/v1")
app.include_router(camera_router, prefix="/api/v1")

# Mount Static File Server
Path("storage").mkdir(exist_ok=True)
app.mount("/storage", StaticFiles(directory="storage"), name="storage")


@app.get("/")
def root():
    return {
        "message": "FaceVault AI Backend is running",
        "docs": "/docs",
        "version": "1.0.0",
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.exception_handler(FaceVaultException)
async def facevault_exception_handler(request: Request, exc: FaceVaultException):
    return JSONResponse(
        status_code=exc.status_code,
        content=error_response(message=exc.message),
    )


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Global unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content=error_response(message="Internal server error", errors={"detail": str(exc)}),
    )
