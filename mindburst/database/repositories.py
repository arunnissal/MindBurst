"""
SQLite Repository Pattern implementation for Captures, Memories, and Entities
"""
from typing import List, Optional
from mindburst.database.database import DatabaseManager
from mindburst.database.models import Capture, Memory, Entity
from mindburst.utils.helpers import current_iso_timestamp

class CaptureRepository:
    def __init__(self, db_manager: Optional[DatabaseManager] = None):
        self.db = db_manager or DatabaseManager.get_instance()

    def create_capture(self, original_text: str, input_source: str = "text") -> Capture:
        timestamp = current_iso_timestamp()
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO captures (original_text, input_source, created_at) VALUES (?, ?, ?);",
                (original_text, input_source, timestamp)
            )
            capture_id = cursor.lastrowid
            conn.commit()
            return Capture(id=capture_id, original_text=original_text, input_source=input_source, created_at=timestamp)

    def get_capture_by_id(self, capture_id: int) -> Optional[Capture]:
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT id, original_text, input_source, created_at FROM captures WHERE id = ?;", (capture_id,))
            row = cursor.fetchone()
            if row:
                return Capture(
                    id=row["id"],
                    original_text=row["original_text"],
                    input_source=row["input_source"] if "input_source" in row.keys() else "text",
                    created_at=row["created_at"]
                )
            return None

    def delete_capture(self, capture_id: int) -> bool:
        """Deletes an uncommitted capture to avoid orphan data on cancel."""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM captures WHERE id = ?;", (capture_id,))
            conn.commit()
            return cursor.rowcount > 0



class MemoryRepository:
    def __init__(self, db_manager: Optional[DatabaseManager] = None):
        self.db = db_manager or DatabaseManager.get_instance()

    def create_memory(self, memory: Memory) -> Memory:
        timestamp = current_iso_timestamp()
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            try:
                cursor.execute("""
                    INSERT INTO memories (
                        capture_id, type, title, details, date, time, category, retention, completed, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """, (
                    memory.capture_id,
                    memory.type,
                    memory.title,
                    memory.details,
                    memory.date,
                    memory.time,
                    memory.category,
                    memory.retention,
                    1 if memory.completed else 0,
                    timestamp,
                    timestamp
                ))
                memory_id = cursor.lastrowid
                memory.id = memory_id
                memory.created_at = timestamp
                memory.updated_at = timestamp

                # Save entities
                self._save_entities(cursor, memory_id, "person", memory.people)
                self._save_entities(cursor, memory_id, "place", memory.places)
                self._save_entities(cursor, memory_id, "item", memory.items)
                self._save_entities(cursor, memory_id, "project", memory.projects)

                conn.commit()
                return memory
            except Exception as e:
                conn.rollback()
                raise e

    def _save_entities(self, cursor, memory_id: int, entity_type: str, items: List[str]):
        for item in items:
            if item and item.strip():
                cursor.execute(
                    "INSERT INTO entities (memory_id, entity_type, name) VALUES (?, ?, ?);",
                    (memory_id, entity_type, item.strip())
                )

    def get_memory_by_id(self, memory_id: int) -> Optional[Memory]:
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT m.*, c.original_text 
                FROM memories m 
                JOIN captures c ON m.capture_id = c.id 
                WHERE m.id = ? AND m.deleted_at IS NULL;
            """, (memory_id,))
            row = cursor.fetchone()
            if not row:
                return None
            
            memory = self._row_to_memory(row)
            self._load_entities(cursor, memory)
            return memory

    def get_memories_by_capture_id(self, capture_id: int) -> List[Memory]:
        """Fetch all memories generated from a specific capture."""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT m.*, c.original_text 
                FROM memories m 
                JOIN captures c ON m.capture_id = c.id 
                WHERE m.capture_id = ? AND m.deleted_at IS NULL
                ORDER BY m.id ASC;
            """, (capture_id,))
            rows = cursor.fetchall()
            memories = []
            for row in rows:
                mem = self._row_to_memory(row)
                self._load_entities(cursor, mem)
                memories.append(mem)
            return memories

    def list_active_memories(
        self,
        category: Optional[str] = None,
        retention: Optional[str] = None,
        search_query: Optional[str] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        limit: int = 100,
        offset: int = 0
    ) -> List[Memory]:
        """Fetch active memories (excluding deleted and temporary completed)."""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            
            query = """
                SELECT m.*, c.original_text 
                FROM memories m 
                JOIN captures c ON m.capture_id = c.id 
                WHERE m.deleted_at IS NULL
                AND NOT (m.retention = 'Temporary' AND m.completed = 1)
            """
            params = []

            if category and category != "All":
                query += " AND m.category = ?"
                params.append(category)

            if retention and retention != "All":
                query += " AND m.retention = ?"
                params.append(retention)

            if start_date and end_date:
                if start_date == end_date:
                    query += " AND (m.date = ? OR (m.date IS NULL AND SUBSTR(m.created_at, 1, 10) = ?))"
                    params.extend([start_date, start_date])
                else:
                    query += " AND ((m.date BETWEEN ? AND ?) OR (m.date IS NULL AND SUBSTR(m.created_at, 1, 10) BETWEEN ? AND ?))"
                    params.extend([start_date, end_date, start_date, end_date])
            elif start_date:
                query += " AND (m.date >= ? OR (m.date IS NULL AND SUBSTR(m.created_at, 1, 10) >= ?))"
                params.extend([start_date, start_date])
            elif end_date:
                query += " AND (m.date <= ? OR (m.date IS NULL AND SUBSTR(m.created_at, 1, 10) <= ?))"
                params.extend([end_date, end_date])


            if search_query and search_query.strip():
                q = f"%{search_query.strip()}%"
                query += """ AND (
                    m.title LIKE ? OR 
                    m.details LIKE ? OR 
                    c.original_text LIKE ? OR 
                    m.category LIKE ? OR
                    m.id IN (SELECT memory_id FROM entities WHERE name LIKE ?)
                )"""
                params.extend([q, q, q, q, q])

            query += " ORDER BY m.created_at DESC LIMIT ? OFFSET ?;"
            params.extend([limit, offset])

            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            memories = []
            for row in rows:
                mem = self._row_to_memory(row)
                self._load_entities(cursor, mem)
                memories.append(mem)
                
            return memories


    def list_deleted_memories(self) -> List[Memory]:
        """Fetch soft-deleted memories for recovery, with entities loaded."""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT m.*, c.original_text 
                FROM memories m 
                JOIN captures c ON m.capture_id = c.id 
                WHERE m.deleted_at IS NOT NULL 
                ORDER BY m.deleted_at DESC;
            """)
            rows = cursor.fetchall()
            memories = []
            for row in rows:
                mem = self._row_to_memory(row)
                self._load_entities(cursor, mem)
                memories.append(mem)
            return memories

    def delete_forever(self, memory_id: int) -> bool:
        """Permanently removes memory record and child entities from SQLite database."""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM entities WHERE memory_id = ?;", (memory_id,))
            cursor.execute("DELETE FROM memories WHERE id = ?;", (memory_id,))
            conn.commit()
            return cursor.rowcount > 0



    def update_memory(self, memory: Memory) -> bool:
        timestamp = current_iso_timestamp()
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE memories SET
                    type = ?,
                    title = ?,
                    details = ?,
                    date = ?,
                    time = ?,
                    category = ?,
                    retention = ?,
                    completed = ?,
                    completed_at = ?,
                    updated_at = ?
                WHERE id = ?;
            """, (
                memory.type,
                memory.title,
                memory.details,
                memory.date,
                memory.time,
                memory.category,
                memory.retention,
                1 if memory.completed else 0,
                memory.completed_at,
                timestamp,
                memory.id
            ))
            
            # Refresh entities
            cursor.execute("DELETE FROM entities WHERE memory_id = ?;", (memory.id,))
            self._save_entities(cursor, memory.id, "person", memory.people)
            self._save_entities(cursor, memory.id, "place", memory.places)
            self._save_entities(cursor, memory.id, "item", memory.items)
            self._save_entities(cursor, memory.id, "project", memory.projects)

            conn.commit()
            return cursor.rowcount > 0

    def soft_delete_memory(self, memory_id: int) -> bool:
        timestamp = current_iso_timestamp()
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("UPDATE memories SET deleted_at = ? WHERE id = ?;", (timestamp, memory_id))
            conn.commit()
            return cursor.rowcount > 0

    def restore_memory(self, memory_id: int) -> bool:
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("UPDATE memories SET deleted_at = NULL WHERE id = ?;", (memory_id,))
            conn.commit()
            return cursor.rowcount > 0

    def _row_to_memory(self, row) -> Memory:
        return Memory(
            id=row["id"],
            capture_id=row["capture_id"],
            type=row["type"],
            title=row["title"],
            details=row["details"] or "",
            date=row["date"],
            time=row["time"],
            category=row["category"],
            retention=row["retention"],
            completed=bool(row["completed"]),
            completed_at=row["completed_at"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
            deleted_at=row["deleted_at"],
            original_text=row["original_text"] if "original_text" in row.keys() else None
        )

    def _load_entities(self, cursor, memory: Memory):
        cursor.execute("SELECT entity_type, name FROM entities WHERE memory_id = ?;", (memory.id,))
        rows = cursor.fetchall()
        memory.people = [r["name"] for r in rows if r["entity_type"] == "person"]
        memory.places = [r["name"] for r in rows if r["entity_type"] == "place"]
        memory.items = [r["name"] for r in rows if r["entity_type"] == "item"]
        memory.projects = [r["name"] for r in rows if r["entity_type"] == "project"]
