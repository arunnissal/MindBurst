"""
Utility helpers for MindBurst
"""
import os
import sys
from datetime import datetime, timezone

def get_app_dir() -> str:
    """Returns directory where app data (db, config) is stored."""
    if "ANDROID_ARGUMENT" in os.environ or hasattr(sys, "getandroidapilevel"):
        # Running on Android
        try:
            from android.storage import app_storage_path # type: ignore
            return app_storage_path()
        except Exception:
            try:
                from jnius import autoclass # type: ignore
                PythonActivity = autoclass('org.kivy.android.PythonActivity')
                return PythonActivity.mActivity.getFilesDir().getAbsolutePath()
            except Exception:
                pass
    
    # Desktop / fallback path
    app_dir = os.path.join(os.path.expanduser("~"), ".mindburst")
    os.makedirs(app_dir, exist_ok=True)
    return app_dir

def current_iso_timestamp() -> str:
    """Return current UTC timestamp in ISO 8601 format."""
    return datetime.now(timezone.utc).isoformat()
