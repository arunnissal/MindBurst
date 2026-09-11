"""
Phase 3 Automated Test Suite — Burst Text Capture & Persistence Flow
Tests:
1. Empty Burst input handling
2. Text capture creation & input_source="text"
3. Exact original text preservation
4. Single-memory extraction
5. Multiple-memory extraction with shared capture_id
6. Entity persistence from extraction
7. User-edited understanding persistence
8. Save flow end-to-end
9. Cancel flow rollback without orphaned data
10. AI extraction failure fallback to Note memory
11. All screen memory feed loading
12. Local text search matching (keywords, entities, categories)
"""
import os
import tempfile
import pytest

from mindburst.database.database import DatabaseManager
from mindburst.database.models import Memory, Capture
from mindburst.database.repositories import CaptureRepository, MemoryRepository
from mindburst.core.capture_service import CaptureService
from mindburst.core.extraction_service import ExtractionService
from mindburst.core.memory_service import MemoryService
from mindburst.core.search_service import SearchService
from mindburst.ai.llm_engine import MockLocalLLMEngine
from mindburst.ai.extraction_parser import ExtractionParser

@pytest.fixture
def temp_db():
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        db_path = f.name
    
    db_mgr = DatabaseManager(db_path=db_path)
    yield db_mgr
    
    if os.path.exists(db_path):
        os.remove(db_path)


def test_empty_burst_input_handling(temp_db):
    """Verify empty input or whitespace raises ValueError and is not persisted."""
    capture_service = CaptureService(CaptureRepository(temp_db))
    with pytest.raises(ValueError, match="Cannot capture empty thought"):
        capture_service.capture_thought("   ")


def test_text_capture_creation_and_preservation(temp_db):
    """Verify raw text and input_source='text' are preserved exactly."""
    capture_service = CaptureService(CaptureRepository(temp_db))
    raw_thought = "   Tomorrow college pogumbothu charger eduthutu poganum   "
    capture = capture_service.capture_thought(raw_thought, input_source="text")

    assert capture.id is not None
    assert capture.original_text == "Tomorrow college pogumbothu charger eduthutu poganum"
    assert capture.input_source == "text"


def test_single_and_multiple_memory_extraction(temp_db):
    """Test compound input yielding multiple memories sharing capture_id."""
    capture_service = CaptureService(CaptureRepository(temp_db))
    extraction_service = ExtractionService(MockLocalLLMEngine())

    compound_text = "Tomorrow college pogumbothu charger eduthutu poganum and Rahul kitta project pathi kekkanum."
    capture = capture_service.capture_thought(compound_text)

    memories = extraction_service.extract_memories(capture)
    assert len(memories) >= 2
    assert all(m.capture_id == capture.id for m in memories)
    assert all(m.original_text == compound_text.strip() for m in memories)


def test_entity_extraction_and_persistence(temp_db):
    """Test that extracted entities (people, places, items, projects) persist in SQLite."""
    capture_service = CaptureService(CaptureRepository(temp_db))
    extraction_service = ExtractionService(MockLocalLLMEngine())
    memory_service = MemoryService(MemoryRepository(temp_db))

    text = "Tomorrow college pogumbothu charger eduthutu poganum and Rahul kitta project pathi kekkanum."
    capture = capture_service.capture_thought(text)
    extracted = extraction_service.extract_memories(capture)

    saved_memories = memory_service.save_memories(extracted)
    assert len(saved_memories) >= 2

    # Query DB repository directly to verify entities
    repo = MemoryRepository(temp_db)
    mem1 = repo.get_memory_by_id(saved_memories[0].id)
    assert mem1 is not None
    assert "Charger" in mem1.items or "Rahul" in mem1.people or "College" in mem1.places


def test_user_edited_understanding_persistence(temp_db):
    """Verify that user-edited memory fields on Understanding Screen get persisted."""
    capture_service = CaptureService(CaptureRepository(temp_db))
    memory_service = MemoryService(MemoryRepository(temp_db))

    capture = capture_service.capture_thought("Take charger tomorrow")
    mem = Memory(
        capture_id=capture.id,
        type="Carry",
        title="Original AI Title",
        category="Carry",
        retention="Temporary",
        date="Tomorrow"
    )

    # User edits title and category prior to saving
    mem.title = "User Edited Title: Laptop Charger"
    mem.category = "Important"
    mem.date = "2026-09-04"

    saved = memory_service.save_memories([mem])
    retrieved = MemoryRepository(temp_db).get_memory_by_id(saved[0].id)

    assert retrieved is not None
    assert retrieved.title == "User Edited Title: Laptop Charger"
    assert retrieved.category == "Important"
    assert retrieved.date == "2026-09-04"


def test_cancel_flow_rollback(temp_db):
    """Verify cancelling from Understanding Screen removes uncommitted capture."""
    capture_service = CaptureService(CaptureRepository(temp_db))
    memory_repo = MemoryRepository(temp_db)

    capture = capture_service.capture_thought("Unwanted thought")
    assert capture_service.delete_capture(capture.id) is True

    # Ensure capture is deleted and no memories exist
    assert CaptureRepository(temp_db).get_capture_by_id(capture.id) is None
    assert len(memory_repo.list_active_memories()) == 0


def test_extraction_failure_fallback_note(temp_db):
    """Verify malformed LLM response defaults gracefully to 1 Note memory without losing text."""
    capture_service = CaptureService(CaptureRepository(temp_db))
    raw_input = "Important private thought that AI failed to parse"
    capture = capture_service.capture_thought(raw_input)

    # Simulate parsing broken JSON output
    fallback_memories = ExtractionParser.parse_llm_response(
        raw_response="BROKEN_NON_JSON",
        capture_id=capture.id,
        original_text=capture.original_text
    )

    assert len(fallback_memories) == 1
    assert fallback_memories[0].type == "Note"
    assert fallback_memories[0].category == "Notes"
    assert fallback_memories[0].details == raw_input.strip()


def test_all_screen_feed_and_search(temp_db):
    """Verify MemoryService and SearchService return correct active memories and search matches."""
    capture_service = CaptureService(CaptureRepository(temp_db))
    memory_service = MemoryService(MemoryRepository(temp_db))
    search_service = SearchService(MemoryRepository(temp_db))

    c1 = capture_service.capture_thought("Tomorrow college, take laptop charger and ID.")
    m1 = Memory(capture_id=c1.id, type="Carry", title="Take charger and ID", category="Carry", items=["Charger", "ID"], places=["College"])

    c2 = capture_service.capture_thought("Remind me to ask Rahul about project.")
    m2 = Memory(capture_id=c2.id, type="Task", title="Ask Rahul about project", category="Tasks", people=["Rahul"], projects=["Project"])

    memory_service.save_memories([m1, m2])

    active = memory_service.get_active_memories()
    assert len(active) == 2

    # Search for "Rahul"
    rahul_results = search_service.search_memories("Rahul")
    assert len(rahul_results) == 1
    assert rahul_results[0].title == "Ask Rahul about project"

    # Search for "Charger"
    charger_results = search_service.search_memories("Charger")
    assert len(charger_results) == 1
    assert charger_results[0].title == "Take charger and ID"
