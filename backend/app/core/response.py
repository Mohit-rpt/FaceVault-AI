"""
Standardized response builder.
"""

from typing import Any, Optional

from app.schemas import StandardResponse


def success_response(data: Any = None, message: str = "Success") -> dict:
    return {
        "success": True,
        "message": message,
        "data": data,
        "errors": None,
    }


def error_response(message: str = "Error", errors: Optional[dict] = None, status_code: int = 500) -> dict:
    return {
        "success": False,
        "message": message,
        "data": None,
        "errors": errors,
    }