from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List

from app.database.database import get_db
from app import schemas, crud

router = APIRouter(prefix="/settings", tags=["Settings"])


@router.get("", response_model=List[schemas.SettingResponse])
def read_settings(db: Session = Depends(get_db)):
    return crud.get_settings(db)


@router.put("/{key}", response_model=schemas.SettingResponse)
def update_setting(key: str, setting: schemas.SettingCreate, db: Session = Depends(get_db)):
    return crud.update_setting(db, key=key, value=setting.setting_value)