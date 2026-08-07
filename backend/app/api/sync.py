"""
Sync API Router — Phase 2 Implementation.

Provides endpoints for:
- GET /sync/version: Returns current server embedding version and last_updated ISO timestamp.
- GET /sync/delta?version=<client_version>: Returns only modified embeddings & persons after client_version.
- GET /sync/bootstrap: Exports full dataset for clean initial installation sync.
- POST /sync/logs: Receives and inserts offline recognition logs.
"""

from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.core.response import success_response, error_response
from app.services.sync_service import SyncService

router = APIRouter(prefix="/sync", tags=["Sync"])


@router.get("/version")
def get_sync_version(db: Session = Depends(get_db)):
    """
    Get current server max embedding_version and last_updated timestamp.
    """
    sync_service = SyncService(db)
    data = sync_service.get_sync_version()
    return success_response(data=data, message="Sync version retrieved")


@router.get("/delta")
def get_sync_delta(
    version: int = Query(0, description="Current client embedding version"),
    db: Session = Depends(get_db),
):
    """
    Get delta changes modified after client_version.
    Returns only new/updated embeddings and deleted embedding IDs.
    """
    sync_service = SyncService(db)
    data = sync_service.get_delta_data(client_version=version)
    return success_response(data=data, message="Delta sync data retrieved")


@router.get("/bootstrap")
def get_sync_bootstrap(db: Session = Depends(get_db)):
    """
    Export complete active dataset snapshot for first installation bootstrap.
    """
    sync_service = SyncService(db)
    data = sync_service.get_bootstrap_data()
    return success_response(data=data, message="Bootstrap sync dataset exported")


@router.post("/logs")
def post_sync_logs(
    logs: List[Dict[str, Any]],
    db: Session = Depends(get_db),
):
    """
    Receive and insert offline recognition logs queued on mobile/edge client.
    """
    sync_service = SyncService(db)
    result = sync_service.process_offline_logs(logs)
    if not result.get("success", False):
        return error_response(message="Failed to insert offline logs", errors=result)
    return success_response(data=result, message=f"Successfully synced {result.get('inserted', 0)} offline logs")
