"""
Search Service
Normalized SQLite text search across original text, title, details, entities, and categories.
"""
from typing import List, Optional
from mindburst.database.repositories import MemoryRepository
from mindburst.database.models import Memory

class SearchService:
    def __init__(self, memory_repo: Optional[MemoryRepository] = None):
        self.memory_repo = memory_repo or MemoryRepository()

    def search_memories(
        self,
        query: Optional[str] = None,
        category: Optional[str] = None,
        retention: Optional[str] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        limit: int = 100
    ) -> List[Memory]:
        """Performs multi-field normalized search for active memories matching all active filters."""
        clean_q = query.strip() if query else None
        clean_cat = category if (category and category != "All") else None
        clean_ret = retention if (retention and retention != "All") else None

        return self.memory_repo.list_active_memories(
            search_query=clean_q,
            category=clean_cat,
            retention=clean_ret,
            start_date=start_date,
            end_date=end_date,
            limit=limit
        )

