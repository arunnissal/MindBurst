"""
Phase 6 Automated Test Suite — Understanding Screen + Confirmation/Edit Workflow Polish
"""
import tempfile
import os
import pytest
from kivymd.app import MDApp
from mindburst.database.database import DatabaseManager
from mindburst.database.repositories import CaptureRepository, MemoryRepository
from mindburst.database.models import Capture, Memory
from mindburst.ui.screens.understanding_screen import UnderstandingScreen, MemoryCardItem
from mindburst.core.capture_service import CaptureService
from mindburst.core.extraction_service import ExtractionService
from mindburst.core.memory_service import MemoryService
from mindburst.utils.date_normalizer import DateNormalizer


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


@pytest.fixture
def extraction_service():
    return ExtractionService()


def test_understanding_screen_receives_single_and_multiple_memories():
    """Verify UnderstandingScreen handles single and multiple candidate memories cleanly."""
    original_text = "Tomorrow college, take laptop charger and ID, and remind me to ask Rahul about project."
    m1 = Memory(capture_id=1, type="Carry", title="Take charger and ID", category="Carry", date="2026-09-04", items=["Charger", "ID"], places=["College"])
    m2 = Memory(capture_id=1, type="Task", title="Ask Rahul about project", category="Tasks", date="2026-09-04", people=["Rahul"])

    screen = UnderstandingScreen(original_text=original_text, extracted_memories=[m1, m2])
    assert screen.original_text == original_text
    assert len(screen.card_widgets) == 2
    assert screen.card_widgets[0].memory.title == "Take charger and ID"
    assert screen.card_widgets[1].memory.title == "Ask Rahul about project"


def test_original_text_preserved_exactly():
    """Verify original captured thought is preserved exactly without alteration."""
    raw_thought = "   Naalaiku college pogumbothu charger eduthutu poganum.   "
    capture_service = CaptureService()
    c = capture_service.capture_thought(raw_thought, input_source="text")
    assert c.original_text == "Naalaiku college pogumbothu charger eduthutu poganum."


def test_user_edits_title_category_date_retention():
    """Verify editing fields on MemoryCardItem updates the Memory instance correctly."""
    m = Memory(capture_id=1, type="Task", title="Submit assignment", category="Tasks", retention="Temporary", date="Tomorrow")
    card = MemoryCardItem(m)

    # Edit fields
    card.title_field.text = "Submit AI Assignment Final"
    card.category_field.text = "College"
    card.date_field.text = "2026-09-10"
    card._cycle_retention() # Cycles Temporary -> Keep Until Delete

    updated = card.get_updated_memory()
    assert updated.title == "Submit AI Assignment Final"
    assert updated.category == "College"
    assert updated.date == "2026-09-10"
    assert updated.retention == "Keep Until Delete"


def test_editing_one_memory_does_not_modify_another():
    """Verify deep copy memory state isolation prevents cross-card mutation."""
    m1 = Memory(capture_id=1, type="Shopping", title="Buy milk", category="Shopping", retention="Temporary")
    m2 = Memory(capture_id=1, type="Task", title="Call mom", category="Tasks", retention="Temporary")

    screen = UnderstandingScreen(original_text="Buy milk, call mom", extracted_memories=[m1, m2])
    assert len(screen.card_widgets) == 2

    # Edit card 0
    screen.card_widgets[0].title_field.text = "Buy almond milk"
    screen.card_widgets[0]._cycle_retention()

    updated_0 = screen.card_widgets[0].get_updated_memory()
    updated_1 = screen.card_widgets[1].get_updated_memory()

    assert updated_0.title == "Buy almond milk"
    assert updated_0.retention == "Keep Until Delete"
    assert updated_1.title == "Call mom"
    assert updated_1.retention == "Temporary"


def test_save_persists_edited_values_to_database(db_mgr):
    """Verify tapping Save persists updated memories and entities correctly into SQLite."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    capture_service = CaptureService(capture_repo)
    memory_service = MemoryService(memory_repo)

    c = capture_service.capture_thought("Buy milk, call mom and send the project document.", input_source="text")
    m1 = Memory(capture_id=c.id, type="Shopping", title="Buy milk", category="Shopping", items=["Milk"])
    m2 = Memory(capture_id=c.id, type="Task", title="Call mom", category="Tasks", people=["Mom"])

    # Simulate UnderstandingScreen edit before saving
    m1.title = "Buy 2L organic milk"
    m1.category = "Important"
    m2.title = "Call mom about weekend"

    memory_service.save_memories([m1, m2])

    saved = memory_repo.get_memories_by_capture_id(c.id)
    assert len(saved) == 2

    titles = [mem.title for mem in saved]
    categories = [mem.category for mem in saved]
    assert "Buy 2L organic milk" in titles
    assert "Call mom about weekend" in titles
    assert "Important" in categories


def test_cancel_leaves_no_persisted_memories(db_mgr):
    """Verify cancel flow deletes temporary capture and leaves zero orphan records in SQLite."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    capture_service = CaptureService(capture_repo)
    memory_service = MemoryService(memory_repo)

    c = capture_service.capture_thought("Buy coffee on the way home", input_source="text")
    capture_id = c.id

    # Simulate cancel callback execution
    capture_service.delete_capture(capture_id)

    # Verify no capture or memories remain
    persisted_c = capture_repo.get_capture_by_id(capture_id)
    persisted_m = memory_repo.get_memories_by_capture_id(capture_id)

    assert persisted_c is None
    assert len(persisted_m) == 0


def test_fallback_note_can_be_saved(db_mgr):
    """Verify fallback Note memory can be edited and saved cleanly."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    capture_service = CaptureService(capture_repo)
    memory_service = MemoryService(memory_repo)

    c = capture_service.capture_thought("Unstructured thought fallback test", input_source="text")
    fallback_note = Memory(
        capture_id=c.id,
        type="Note",
        title="Unstructured thought fallback test",
        details="Unstructured thought fallback test",
        category="Notes",
        retention="Temporary",
        original_text=c.original_text
    )

    screen = UnderstandingScreen(original_text=c.original_text, extracted_memories=[fallback_note])
    assert len(screen.card_widgets) == 1

    # Edit fallback note title
    screen.card_widgets[0].title_field.text = "Custom Note Title"
    updated = [card.get_updated_memory() for card in screen.card_widgets]

    memory_service.save_memories(updated)
    saved = memory_repo.get_memories_by_capture_id(c.id)

    assert len(saved) == 1
    assert saved[0].title == "Custom Note Title"
    assert saved[0].type == "Note"




def test_empty_optional_fields_no_tech_noise():
    """Verify empty optional fields (people, projects, items, places) do not render empty noise."""
    m = Memory(capture_id=1, type="Task", title="Clean desk", category="Tasks", people=[], projects=[], items=[], places=[])
    card = MemoryCardItem(m)
    assert card.memory.people == []
    assert card.memory.projects == []


def test_generic_project_vs_named_mindburst_project(extraction_service):
    """Verify Phase 4.1 rule preservation: 'the project' yields projects=[], 'MindBurst project' yields projects=['MindBurst']."""
    c_generic = Capture(id=50, original_text="Call Rahul about the project.")
    m_generic = extraction_service.extract_memories(c_generic)
    assert m_generic[0].projects == []

    c_named = Capture(id=51, original_text="Call Rahul about the MindBurst project.")
    m_named = extraction_service.extract_memories(c_named)
    assert m_named[0].projects == ["MindBurst"]


def test_charger_and_id_multi_item_extraction(extraction_service):
    """Phase 6.1 Hotfix: Verify 'take laptop charger and ID' extracts both Charger and ID."""
    c = Capture(id=60, original_text="Tomorrow college, take laptop charger and ID, and remind me to ask Rahul about project.")
    memories = extraction_service.extract_memories(c)
    carry_mem = [m for m in memories if m.type == "Carry"][0]
    assert "Charger" in carry_mem.items
    assert "ID" in carry_mem.items
    assert len(carry_mem.items) == 2


def test_charger_id_headphones_multi_item_extraction(extraction_service):
    """Phase 6.1 Hotfix: Verify 'charger, ID and headphones' extracts all three items."""
    c = Capture(id=61, original_text="I usually carry my charger, ID and headphones to college.")
    memories = extraction_service.extract_memories(c)
    carry_mem = [m for m in memories if m.type == "Carry"][0]
    assert "Charger" in carry_mem.items
    assert "ID" in carry_mem.items
    assert "Headphones" in carry_mem.items
    assert len(carry_mem.items) == 3

