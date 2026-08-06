"""
Utility functions.
"""

from typing import Optional


def get_image_url(local_path: Optional[str]) -> Optional[str]:
    """
    Convert local filesystem path to public URL.
    
    Example: storage/faces/person_1/abc.jpg → /storage/faces/person_1/abc.jpg
    """
    if not local_path:
        return None
    
    # Remove leading 'storage/' and prepend '/storage/'
    if local_path.startswith("storage/"):
        return "/" + local_path
    if local_path.startswith("/storage/"):
        return local_path
    
    return "/storage/" + local_path.replace("\\", "/")