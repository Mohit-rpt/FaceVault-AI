"""
Version Service — Phase 2 Placeholder.

Will handle:
- AI model version tracking
- Compatibility checks between server and edge model versions
- Model update availability notifications

Not instantiated until Phase 2 activation.
"""

import logging
from typing import Optional

logger = logging.getLogger(__name__)


class VersionService:
    """AI model version management for edge device support."""

    CURRENT_MODEL = "buffalo_sc"
    CURRENT_VERSION = "1.0"

    def get_server_version(self) -> dict:
        """Get current server model version info."""
        raise NotImplementedError("VersionService will be implemented in Phase 2")

    def check_compatibility(self, client_version: str) -> dict:
        """Check if a client model version is compatible with server."""
        raise NotImplementedError("VersionService will be implemented in Phase 2")

    def get_latest_model_info(self) -> dict:
        """Get information about the latest available model."""
        raise NotImplementedError("VersionService will be implemented in Phase 2")
