"""
Phase 2 Automated Test Suite — Database & Persistence Hardening
Tests SQLite schema versioning, migrations, capture sources, multi-memory linkage,
multi-entity relationships, normalized date persistence, retention policy behavior,
soft deletion/restoration, and transaction safety.
"""
import os
import sqlite3
import tempfile
import pytest

from mindburst.database.database import DatabaseManager
from mindburst.database.models import Capture, Memory
from mindburst.database.repositories import CaptureRepository, MemoryRepository
from mindburst.core.retention_service import RetentionService

@pytest.fixture
def temp_db():
    """Fixture supplying an isolated temporary SQLite database."""
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        db_path = f.name
    
    db_mgr = DatabaseManager(db_path=db_path)
    yield db_mgr
    
    if os.path.exists(db_path):
        os.remove(db_path)


def test_schema_migration_v1_to_v2():
    """Test upgrading an existing version 1 database to version 2 schema."""
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        v1_path = f.name
    f.close()

    try:
        # Manually build v1 database schema without input_source column
        conn = sqlite3.connect(v1_path)
        cursor = conn.cursor()
        cursor.execute("CREATE TABLE captures (id INTEGER PRIMARY KEY AUTOINCREMENT, original_text TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);")
        cursor.execute("CREATE TABLE memories (id INTEGER PRIMARY KEY AUTOINCREMENT, capture_id INTEGER NOT NULL, type TEXT NOT NULL DEFAULT 'Note', title TEXT NOT NULL, details TEXT DEFAULT '', date TEXT, time TEXT, category TEXT NOT NULL DEFAULT 'Notes', retention TEXT NOT NULL DEFAULT 'Temporary', completed INTEGER NOT NULL DEFAULT 0, completed_at TIMESTAMP, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, deleted_at TIMESTAMP);")
        cursor.execute("CREATE TABLE entities (id INTEGER PRIMARY KEY AUTOINCREMENT, memory_id INTEGER NOT NULL, entity_type TEXT NOT NULL, name TEXT NOT NULL);")
        cursor.execute("CREATE TABLE schema_migrations (version INTEGER PRIMARY KEY, applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);")
        cursor.execute("INSERT INTO schema_migrations (version) VALUES (1);")
        conn.commit()
        conn.close()

        # Initialize DatabaseManager on v1_path (should trigger migration v1 -> v2)
        db_mgr = DatabaseManager(db_path=v1_path)
        
        with db_mgr.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("PRAGMA table_info(captures);")
            cols = [r["name"] for r in cursor.fetchall()]
            assert "input_source" in cols

            cursor.execute("SELECT MAX(version) as max_v FROM schema_migrations;")
            row = cursor.fetchone()
            assert row["max_v"] == 2

    finally:
        try:
            if os.path.exists(v1_path):
                os.remove(v1_path)
        except OSError:
            pass



def test_capture_input_sources(temp_db):
    """Test capture persistence with text vs voice input sources."""
    capture_repo = CaptureRepository(temp_db)

    c_text = capture_repo.create_capture("Remember to submit report", input_source="text")
    assert c_text.id is not None
    assert c_text.input_source == "text"

    c_voice = capture_repo.create_capture("Voice memo audio transcript", input_source="voice")
    assert c_voice.id is not None
    assert c_voice.input_source == "voice"

    # Verify retrieval
    retrieved_voice = capture_repo.get_capture_by_id(c_voice.id)
    assert retrieved_voice is not None
    assert retrieved_voice.input_source == "voice"
    assert retrieved_voice.original_text == "Voice memo audio transcript"


def test_capture_to_multiple_memories(temp_db):
    """Test single capture yielding multiple memory records."""
    capture_repo = CaptureRepository(temp_db)
    memory_repo = MemoryRepository(temp_db)

    original_raw = "Tomorrow college pogumbothu charger eduthutu poganum and Rahul kitta project pathi kekkanum."
    capture = capture_repo.create_capture(original_raw)

    mem1 = Memory(
        capture_id=capture.id,
        type="Carry",
        title="Take charger",
        details="Charger for college",
        date="Tomorrow",
        category="Carry",
        retention="Temporary",
        items=["Charger"],
        places=["College"]
    )
    mem2 = Memory(
        capture_id=capture.id,
        type="Task",
        title="Ask Rahul about project",
        details="Discuss project details",
        date="Tomorrow",
        category="Tasks",
        retention="Temporary",
        people=["Rahul"],
        projects=["Project"]
    )

    memory_repo.create_memory(mem1)
    memory_repo.create_memory(mem2)

    linked_memories = memory_repo.get_memories_by_capture_id(capture.id)
    assert len(linked_memories) == 2
    titles = [m.title for m in linked_memories]
    assert "Take charger" in titles
    assert "Ask Rahul about project" in titles
    assert all(m.original_text == original_raw for m in linked_memories)


def test_multiple_entities_of_same_type(temp_db):
    """Test persisting multiple entities of the same type under a single memory."""
    capture_repo = CaptureRepository(temp_db)
    memory_repo = MemoryRepository(temp_db)

    capture = capture_repo.create_capture("Take my charger, ID and headphones to college tomorrow.")
    mem = Memory(
        capture_id=capture.id,
        type="Carry",
        title="College items",
        details="Take charger, ID, headphones",
        date="Tomorrow",
        category="Carry",
        retention="Temporary",
        items=["Charger", "ID", "Headphones"],
        places=["College"]
    )
    saved = memory_repo.create_memory(mem)

    retrieved = memory_repo.get_memory_by_id(saved.id)
    assert retrieved is not None
    assert len(retrieved.items) == 3
    assert "Charger" in retrieved.items
    assert "ID" in retrieved.items
    assert "Headphones" in retrieved.items
    assert len(retrieved.places) == 1
    assert "College" in retrieved.places


def test_normalized_and_relative_date_persistence(temp_db):
    """Test storing normalized and relative date strings."""
    capture_repo = CaptureRepository(temp_db)
    memory_repo = MemoryRepository(temp_db)

    capture = capture_repo.create_capture("Various date tests")
    dates_to_test = ["Today", "Tomorrow", "Yesterday", "2026-09-04", "This Friday", "Next Monday"]

    for d in dates_to_test:
        mem = Memory(
            capture_id=capture.id,
            type="Note",
            title=f"Event on {d}",
            date=d,
            category="Notes"
        )
        saved = memory_repo.create_memory(mem)
        retrieved = memory_repo.get_memory_by_id(saved.id)
        assert retrieved is not None
        assert retrieved.date == d


def test_retention_modes_and_completion_behavior(temp_db):
    """Test behavior across Temporary, Keep Until Delete, and Permanent retention modes."""
    capture_repo = CaptureRepository(temp_db)
    memory_repo = MemoryRepository(temp_db)

    capture = capture_repo.create_capture("Retention test capture")

    # 1. Temporary Memory
    mem_temp = memory_repo.create_memory(Memory(
        capture_id=capture.id,
        type="Carry",
        title="Temp item",
        retention="Temporary",
        completed=True
    ))

    # 2. Keep Until Delete Memory
    mem_keep = memory_repo.create_memory(Memory(
        capture_id=capture.id,
        type="Task",
        title="Keep item",
        retention="Keep Until Delete",
        completed=True
    ))

    # 3. Permanent Memory
    mem_perm = memory_repo.create_memory(Memory(
        capture_id=capture.id,
        type="Idea",
        title="Permanent item",
        retention="Permanent",
        completed=True
    ))

    active_memories = memory_repo.list_active_memories()
    active_titles = [m.title for m in active_memories]

    # Temporary completed memory must NOT appear in active memories feed
    assert "Temp item" not in active_titles

    # Keep Until Delete and Permanent completed memories MUST remain in active feed
    assert "Keep item" in active_titles
    assert "Permanent item" in active_titles

    # Check RetentionService helpers
    assert RetentionService.is_visible_in_active_feed(mem_temp) is False
    assert RetentionService.is_visible_in_active_feed(mem_keep) is True
    assert RetentionService.is_visible_in_active_feed(mem_perm) is True


def test_soft_delete_and_restore(temp_db):
    """Test soft deletion and recovery workflow."""
    capture_repo = CaptureRepository(temp_db)
    memory_repo = MemoryRepository(temp_db)

    capture = capture_repo.create_capture("Delete test")
    mem = memory_repo.create_memory(Memory(
        capture_id=capture.id,
        type="Note",
        title="To be deleted"
    ))

    # Perform soft delete
    assert memory_repo.soft_delete_memory(mem.id) is True

    # Verify excluded from get_memory_by_id and active list
    assert memory_repo.get_memory_by_id(mem.id) is None
    active_ids = [m.id for m in memory_repo.list_active_memories()]
    assert mem.id not in active_ids

    # Verify present in list_deleted_memories
    deleted_list = memory_repo.list_deleted_memories()
    deleted_ids = [m.id for m in deleted_list]
    assert mem.id in deleted_ids

    # Restore memory
    assert memory_repo.restore_memory(mem.id) is True
    restored = memory_repo.get_memory_by_id(mem.id)
    assert restored is not None
    assert restored.title == "To be deleted"


def test_transaction_rollback_safety(temp_db):
    """Verify transaction safety and rollback on error."""
    memory_repo = MemoryRepository(temp_db)

    # Attempt inserting a memory with non-existent capture_id (violating FOREIGN KEY PRAGMA)
    invalid_mem = Memory(
        capture_id=99999, # Non-existent
        type="Task",
        title="Invalid Foreign Key",
        items=["Orphan Item"]
    )

    with pytest.raises(sqlite3.IntegrityError):
        memory_repo.create_memory(invalid_mem)

    # Verify no entity rows were orphaned
    with temp_db.get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) as count FROM entities WHERE name = 'Orphan Item';")
        row = cursor.fetchone()
        assert row["count"] == 0
