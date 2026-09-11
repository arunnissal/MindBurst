"""
Retention Service
Enforces lifecycle policies:
- Temporary: Completed items are filtered from active memory browser.
- Keep Until Delete: Retained even when completed until explicit user deletion.
- Permanent: Never automatically removed.
"""
from typing import List
from mindburst.database.models import Memory

class RetentionService:
    @staticmethod
    def is_visible_in_active_feed(memory: Memory) -> bool:
        """Determines if a memory should be displayed in the active memories feed."""
        if memory.deleted_at is not None:
            return False
        if memory.retention == "Temporary" and memory.completed:
            return False
        return True
