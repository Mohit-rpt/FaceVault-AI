"""
Global exception classes for FaceVault AI.
"""

from fastapi import HTTPException, status


class FaceVaultException(Exception):
    """Base exception."""
    def __init__(self, message: str = "Something went wrong", status_code: int = 500):
        self.message = message
        self.status_code = status_code
        super().__init__(self.message)


class NotFoundException(FaceVaultException):
    def __init__(self, resource: str = "Resource"):
        super().__init__(f"{resource} not found", status.HTTP_404_NOT_FOUND)


class ValidationException(FaceVaultException):
    def __init__(self, message: str = "Validation failed"):
        super().__init__(message, status.HTTP_422_UNPROCESSABLE_ENTITY)


class UnauthorizedException(FaceVaultException):
    def __init__(self, message: str = "Unauthorized"):
        super().__init__(message, status.HTTP_401_UNAUTHORIZED)


class DuplicateException(FaceVaultException):
    def __init__(self, message: str = "Duplicate entry"):
        super().__init__(message, status.HTTP_409_CONFLICT)