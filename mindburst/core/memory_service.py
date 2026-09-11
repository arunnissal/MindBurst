"""
Memory Service
Business logic for managing memories, completions, and persistence.
"""
from typing import List, Optional
from datetime import datetime, timezone
from mindburst.database.repositories import MemoryRepository
from mindburst.database.models import Memory
from mindburst.utils.helpers import current_iso_timestamp

class MemoryService:
    def __init__(self, memory_repo: Optional[MemoryRepository] = None):
        self.memory_repo = memory_repo or MemoryRepository()

    def save_memories(self, memories: List[Memory]) -> List[Memory]:
        saved_memories = []
        for mem in memories:
            saved = self.memory_repo.create_memory(mem)
            saved_memories.append(saved)
        return saved_memories

    def toggle_completion(self, memory_id: int) -> Optional[Memory]:
        memory = self.memory_repo.get_memory_by_id(memory_id)
        if not memory:
            return None

        memory.completed = not memory.completed
        memory.completed_at = current_iso_timestamp() if memory.completed else None
        self.memory_repo.update_memory(memory)
        return memory

    def update_memory(self, memory: Memory) -> bool:
        return self.memory_repo.update_memory(memory)

    def soft_delete_memory(self, memory_id: int) -> bool:
        return self.memory_repo.soft_delete_memory(memory_id)

    def restore_memory(self, memory_id: int) -> bool:
        return self.memory_repo.restore_memory(memory_id)

    def get_deleted_memories(self) -> List[Memory]:
        return self.memory_repo.list_deleted_memories()

    def delete_forever(self, memory_id: int) -> bool:
        return self.memory_repo.delete_forever(memory_id)


    def get_active_memories(
        self,
        category: Optional[str] = None,
        retention: Optional[str] = None,
        search_query: Optional[str] = None,
        limit: int = 100,
        offset: int = 0
    ) -> List[Memory]:
        return self.memory_repo.list_active_memories(
            category=category,
            retention=retention,
            search_query=search_query,
            limit=limit,
            offset=offset
        )
