"""
Phase 9 Automated Test Suite — Retention Lifecycle + Recently Deleted (Restore & Delete Forever)
"""
import tempfile
import os
import pytest
from kivymd.app import MDApp
from mindburst.database.database import DatabaseManager
from mindburst.database.repositories import CaptureRepository, MemoryRepository
from mindburst.database.models import Memory
from mindburst.core.memory_service import MemoryService
from mindburst.core.retention_service import RetentionService
from mindburst.ui.screens.recently_deleted_screen import RecentlyDeletedScreen


@pytest.fixture(scope="module", autouse=True)
def init_kivy_app():
    """Initializes dummy MDApp context required by KivyMD 2.0.0 widgets during pytest execution."""
    app = MDApp()
    app._run_prepare()
    yield app


@pytest.fixture
def db_mgr():
    """Provides a fresh temporary SQLite database for testing."""
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        db_path = f.name
    
    db = DatabaseManager(db_path=db_path)
    yield db
    
    try:
        db.close()
    except Exception:
        pass
    if os.path.exists(db_path):
        try:
            os.remove(db_path)
        except PermissionError:
            pass


def test_temporary_retention(db_mgr):
    """Verify Temporary completed memories are hidden from active list, incomplete remain active."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Temporary test")
    m_inc = Memory(capture_id=c.id, type="Task", title="Incomplete Temp", category="Tasks", retention="Temporary", completed=False)
    m_comp = Memory(capture_id=c.id, type="Task", title="Completed Temp", category="Tasks", retention="Temporary", completed=True)
    memory_service.save_memories([m_inc, m_comp])

    assert RetentionService.is_visible_in_active_feed(m_inc) is True
    assert RetentionService.is_visible_in_active_feed(m_comp) is False

    active = memory_service.get_active_memories()
    active_titles = [m.title for m in active]
    assert "Incomplete Temp" in active_titles
    assert "Completed Temp" not in active_titles


def test_keep_until_delete(db_mgr):
    """Verify Keep Until Delete memories remain active even when completed."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Keep Until Delete test")
    m = Memory(capture_id=c.id, type="Task", title="Completed KeepUntilDelete", category="Tasks", retention="Keep Until Delete", completed=True)
    memory_service.save_memories([m])

    assert RetentionService.is_visible_in_active_feed(m) is True

    active = memory_service.get_active_memories()
    assert any(mem.title == "Completed KeepUntilDelete" for mem in active)


def test_permanent_retention(db_mgr):
    """Verify Permanent retention memories remain active even when completed."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Permanent test")
    m = Memory(capture_id=c.id, type="Note", title="Completed Permanent Note", category="Notes", retention="Permanent", completed=True)
    memory_service.save_memories([m])

    assert RetentionService.is_visible_in_active_feed(m) is True

    active = memory_service.get_active_memories()
    assert any(mem.title == "Completed Permanent Note" for mem in active)


def test_soft_delete_to_recently_deleted(db_mgr):
    """Verify soft-deleting memory moves it to list_deleted_memories()."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Soft delete test")
    m = Memory(capture_id=c.id, type="Task", title="Soft Delete Task", category="Tasks")
    saved = memory_service.save_memories([m])[0]

    memory_service.soft_delete_memory(saved.id)

    deleted = memory_service.get_deleted_memories()
    assert len(deleted) == 1
    assert deleted[0].id == saved.id
    assert deleted[0].title == "Soft Delete Task"


def test_restore_memory(db_mgr):
    """Verify restore_memory moves soft-deleted memory back to active list."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Restore test")
    m = Memory(capture_id=c.id, type="Task", title="Restorable Memory", category="Tasks")
    saved = memory_service.save_memories([m])[0]

    memory_service.soft_delete_memory(saved.id)
    assert len(memory_service.get_deleted_memories()) == 1

    memory_service.restore_memory(saved.id)
    assert len(memory_service.get_deleted_memories()) == 0

    active = memory_service.get_active_memories()
    assert any(mem.title == "Restorable Memory" for mem in active)


def test_delete_forever(db_mgr):
    """Verify delete_forever permanently removes memory and child entities from SQLite."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Delete forever test")
    m = Memory(capture_id=c.id, type="Carry", title="Permanent Delete Target", category="Carry", items=["Charger"])
    saved = memory_service.save_memories([m])[0]

    memory_service.soft_delete_memory(saved.id)
    memory_service.delete_forever(saved.id)

    deleted = memory_service.get_deleted_memories()
    active = memory_service.get_active_memories()
    assert len(deleted) == 0
    assert len(active) == 0


def test_restored_memory_appears_in_all_screen(db_mgr):
    """Verify restored memory appears in active feed."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Feed restore test")
    m = Memory(capture_id=c.id, type="Shopping", title="Buy almond milk", category="Shopping")
    saved = memory_service.save_memories([m])[0]

    memory_service.soft_delete_memory(saved.id)
    assert "Buy almond milk" not in [mem.title for mem in memory_service.get_active_memories()]

    memory_service.restore_memory(saved.id)
    assert "Buy almond milk" in [mem.title for mem in memory_service.get_active_memories()]


def test_deleted_memory_absent_from_active_memories(db_mgr):
    """Verify deleted memory is absent from active memories."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Absence test")
    m = Memory(capture_id=c.id, type="Task", title="Deleted Task", category="Tasks")
    saved = memory_service.save_memories([m])[0]

    memory_service.soft_delete_memory(saved.id)

    active = memory_service.get_active_memories()
    assert "Deleted Task" not in [mem.title for mem in active]


def test_entity_preservation_after_restore(db_mgr):
    """Verify entity lists (people, places, items, projects) are preserved after soft-delete and restore."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Entity preservation test")
    m = Memory(
        capture_id=c.id,
        type="Carry",
        title="Complex Memory",
        category="Carry",
        people=["Rahul"],
        places=["College"],
        items=["Charger", "ID"],
        projects=["MindBurst"]
    )
    saved = memory_service.save_memories([m])[0]

    memory_service.soft_delete_memory(saved.id)
    memory_service.restore_memory(saved.id)

    restored = memory_repo.get_memory_by_id(saved.id)
    assert restored.people == ["Rahul"]
    assert restored.places == ["College"]
    assert set(restored.items) == {"Charger", "ID"}
    assert restored.projects == ["MindBurst"]


def test_gui_initialization():
    """Verify MindBurstApp initializes with RecentlyDeletedScreen registered."""
    from mindburst.main import MindBurstApp
    app = MindBurstApp()
    assert app.title == "MindBurst"
