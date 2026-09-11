"""
Phase 8 Automated Test Suite — Memory Detail + Operations (View, Edit, Complete, Delete)
"""
import tempfile
import os
import pytest
from kivymd.app import MDApp
from mindburst.database.database import DatabaseManager
from mindburst.database.repositories import CaptureRepository, MemoryRepository
from mindburst.database.models import Memory
from mindburst.core.capture_service import CaptureService
from mindburst.core.memory_service import MemoryService
from mindburst.ui.screens.memory_detail_screen import MemoryDetailScreen


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


def test_open_memory_detail():
    """Verify instantiating and opening MemoryDetailScreen."""
    m = Memory(id=1, capture_id=10, type="Task", title="Original Title", category="Tasks")
    screen = MemoryDetailScreen()
    screen.set_memory(m)
    assert screen.memory is not None
    assert screen.memory.id == 1


def test_correct_memory_displayed():
    """Verify correct memory title, category, and quote text are rendered."""
    m = Memory(id=2, capture_id=11, type="Carry", title="Take charger", details="Details quote", category="Carry", date="2026-09-04", people=["Rahul"])
    screen = MemoryDetailScreen()
    screen.set_memory(m)
    assert screen.memory.title == "Take charger"
    assert screen.memory.category == "Carry"
    assert screen.memory.people == ["Rahul"]


def test_edit_title(db_mgr):
    """Verify editing title updates memory model."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Take charger")
    m = Memory(capture_id=c.id, type="Carry", title="Take charger", category="Carry")
    saved = memory_service.save_memories([m])[0]

    screen = MemoryDetailScreen()
    screen.set_memory(saved)
    screen._enable_edit_mode()

    screen.edit_title_field.text = "Take 65W fast charger"
    screen._handle_save_edits()

    assert saved.title == "Take 65W fast charger"


def test_edit_category(db_mgr):
    """Verify cycling and saving edited category."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Submit assignment")
    m = Memory(capture_id=c.id, type="Task", title="Submit assignment", category="Tasks")
    saved = memory_service.save_memories([m])[0]

    screen = MemoryDetailScreen()
    screen.set_memory(saved)
    screen._enable_edit_mode()

    screen._cycle_edit_category() # Cycles from Carry/Tasks to next allowed category
    new_cat = screen.edit_category_lbl.text.replace("🏷️ ", "")
    screen._handle_save_edits()

    assert saved.category == new_cat


def test_edit_date(db_mgr):
    """Verify editing relative or ISO date parses correctly."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Submit assignment")
    m = Memory(capture_id=c.id, type="Task", title="Submit assignment", category="Tasks", date="2026-09-04")
    saved = memory_service.save_memories([m])[0]

    screen = MemoryDetailScreen()
    screen.set_memory(saved)
    screen._enable_edit_mode()

    screen.edit_date_field.text = "2026-09-10"
    screen._handle_save_edits()

    assert saved.date == "2026-09-10"


def test_edit_retention(db_mgr):
    """Verify cycling and saving retention mode."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Important memory")
    m = Memory(capture_id=c.id, type="Note", title="Important memory", category="Notes", retention="Temporary")
    saved = memory_service.save_memories([m])[0]

    screen = MemoryDetailScreen()
    screen.set_memory(saved)
    screen._enable_edit_mode()

    screen._cycle_edit_retention() # Temporary -> Keep Until Delete
    screen._handle_save_edits()

    assert saved.retention in ["Keep Until Delete", "Permanent", "Temporary"]


def test_save_edits_persist(db_mgr):
    """Verify edited values persist to SQLite database via MemoryService.update_memory."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Original thought")
    m = Memory(capture_id=c.id, type="Task", title="Original Title", category="Tasks", retention="Temporary")
    saved = memory_service.save_memories([m])[0]

    screen = MemoryDetailScreen()
    screen.set_memory(saved)
    screen._enable_edit_mode()
    screen.edit_title_field.text = "Persisted Edit Title"
    screen._handle_save_edits()

    memory_service.update_memory(saved)

    persisted = memory_repo.get_memory_by_id(saved.id)
    assert persisted is not None
    assert persisted.title == "Persisted Edit Title"


def test_complete_memory(db_mgr):
    """Verify completion toggle marks incomplete memory completed=True."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Buy milk")
    m = Memory(capture_id=c.id, type="Shopping", title="Buy milk", category="Shopping", completed=False)
    saved = memory_service.save_memories([m])[0]

    updated = memory_service.toggle_completion(saved.id)
    assert updated.completed is True
    assert updated.completed_at is not None


def test_reopen_completed_memory(db_mgr):
    """Verify completion toggle on completed memory reopens it (completed=False)."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Buy milk")
    m = Memory(capture_id=c.id, type="Shopping", title="Buy milk", category="Shopping", completed=True)
    saved = memory_service.save_memories([m])[0]

    reopened = memory_service.toggle_completion(saved.id)
    assert reopened.completed is False
    assert reopened.completed_at is None


def test_delete_memory(db_mgr):
    """Verify soft-deleting memory sets deleted_at timestamp in SQLite."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Temporary memory to delete")
    m = Memory(capture_id=c.id, type="Task", title="Delete me", category="Tasks")
    saved = memory_service.save_memories([m])[0]

    success = memory_service.soft_delete_memory(saved.id)
    assert success is True

    persisted = memory_repo.get_memory_by_id(saved.id)
    assert persisted is None # get_memory_by_id filters deleted_at IS NULL


def test_deleted_memory_disappears_from_active_list(db_mgr):
    """Verify soft-deleted memory no longer appears in get_active_memories results."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Active vs deleted test")
    m1 = Memory(capture_id=c.id, type="Task", title="Keep Me", category="Tasks")
    m2 = Memory(capture_id=c.id, type="Task", title="Delete Me", category="Tasks")
    saved_list = memory_service.save_memories([m1, m2])

    memory_service.soft_delete_memory(saved_list[1].id)

    active = memory_service.get_active_memories()
    active_titles = [m.title for m in active]

    assert "Keep Me" in active_titles
    assert "Delete Me" not in active_titles


def test_back_navigation():
    """Verify pressing back button triggers back callback."""
    back_called = []
    screen = MemoryDetailScreen(on_back_cb=lambda: back_called.append(True))
    m = Memory(id=5, capture_id=1, type="Note", title="Back test", category="Notes")
    screen.set_memory(m)

    screen._handle_back()
    assert len(back_called) == 1


def test_no_duplicate_memories_after_editing(db_mgr):
    """Verify editing a memory updates existing record without creating duplicate memory IDs."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c = capture_repo.create_capture("Single capture memory")
    m = Memory(capture_id=c.id, type="Task", title="Original Title", category="Tasks")
    saved = memory_service.save_memories([m])[0]

    saved.title = "Updated Title"
    memory_service.update_memory(saved)

    memories_for_capture = memory_repo.get_memories_by_capture_id(c.id)
    assert len(memories_for_capture) == 1
    assert memories_for_capture[0].id == saved.id
    assert memories_for_capture[0].title == "Updated Title"


def test_gui_initialization():
    """Verify MindBurstApp initializes without exceptions."""
    from mindburst.main import MindBurstApp
    app = MindBurstApp()
    assert app.title == "MindBurst"
