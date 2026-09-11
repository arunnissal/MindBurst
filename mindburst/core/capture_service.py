"""
Capture Service
Handles immediate raw thought capture into SQLite captures table.
"""
from typing import Optional
from mindburst.database.repositories import CaptureRepository
from mindburst.database.models import Capture

class CaptureService:
    def __init__(self, capture_repo: Optional[CaptureRepository] = None):
        self.capture_repo = capture_repo or CaptureRepository()

    def capture_thought(self, raw_text: str, input_source: str = "text") -> Capture:
        """Stores the user's raw input text immediately without modification."""
        cleaned_text = raw_text.strip()
        if not cleaned_text:
            raise ValueError("Cannot capture empty thought.")
        return self.capture_repo.create_capture(raw_text.strip(), input_source=input_source)

    def delete_capture(self, capture_id: int) -> bool:
        """Removes an uncommitted capture upon user cancellation."""
        return self.capture_repo.delete_capture(capture_id)

