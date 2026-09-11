"""
Phase 1 Automated Test Suite for MindBurst
Validates:
1. SQLite Database & Schema creation
2. Capture & Memory Repositories CRUD
3. Local LLM Engine Abstraction & Mock execution
4. Structured Extraction Parsing & Note fallback
5. Memory Answerer Grounded Q&A
6. Core Services integration
"""
import os
import tempfile
import pytest

from mindburst.database.database import DatabaseManager
from mindburst.database.models import Capture, Memory
from mindburst.database.repositories import CaptureRepository, MemoryRepository
from mindburst.ai.llm_engine import MockLocalLLMEngine
from mindburst.ai.extraction_parser import ExtractionParser
from mindburst.ai.memory_answerer import MemoryAnswerer
from mindburst.core.capture_service import CaptureService
from mindburst.core.extraction_service import ExtractionService
from mindburst.core.memory_service import MemoryService
from mindburst.core.search_service import SearchService

@pytest.fixture
def temp_db():
    """Fixture supplying an isolated temporary SQLite database."""
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        db_path = f.name
    
    db_mgr = DatabaseManager(db_path=db_path)
    yield db_mgr
    
    # Cleanup
    if os.path.exists(db_path):
        os.remove(db_path)

def test_database_initialization(temp_db):
    """Verify SQLite tables are created properly."""
    with temp_db.get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = [row["name"] for row in cursor.fetchall()]
        
        assert "captures" in tables
        assert "memories" in tables
        assert "entities" in tables
        assert "schema_migrations" in tables

def test_capture_and_memory_crud(temp_db):
    """Verify capture creation and memory persistence."""
    capture_repo = CaptureRepository(temp_db)
    memory_repo = MemoryRepository(temp_db)

    # 1. Create Capture
    original_text = "Tomorrow college pogumbothu charger eduthutu poganum"
    capture = capture_repo.create_capture(original_text)
    assert capture.id is not None
    assert capture.original_text == original_text

    # 2. Create Memory
    mem = Memory(
        capture_id=capture.id,
        type="Carry",
        title="Take charger",
        details="College charger",
        date="Tomorrow",
        category="Carry",
        retention="Temporary",
        items=["Charger"],
        places=["College"]
    )
    saved_mem = memory_repo.create_memory(mem)
    assert saved_mem.id is not None

    # 3. Retrieve Memory
    retrieved = memory_repo.get_memory_by_id(saved_mem.id)
    assert retrieved is not None
    assert retrieved.title == "Take charger"
    assert "Charger" in retrieved.items
    assert "College" in retrieved.places
    assert retrieved.original_text == original_text

def test_extraction_service_and_parser(temp_db):
    """Test Local LLM extraction and JSON parsing fallback."""
    capture_service = CaptureService(CaptureRepository(temp_db))
    extraction_service = ExtractionService(MockLocalLLMEngine())

    text = "Tomorrow college pogumbothu charger eduthutu poganum and Rahul kitta project pathi kekkanum."
    capture = capture_service.capture_thought(text)

    memories = extraction_service.extract_memories(capture)
    assert len(memories) >= 2
    
    types = [m.type for m in memories]
    assert "Carry" in types
    assert "Task" in types

def test_malformed_json_fallback(temp_db):
    """Verify malformed LLM response falls back safely to Note without crashing."""
    malformed_json = "This is not json at all! System broken!"
    memories = ExtractionParser.parse_llm_response(
        raw_response=malformed_json,
        capture_id=1,
        original_text="Emergency note text"
    )
    assert len(memories) == 1
    assert memories[0].type == "Note"
    assert memories[0].details == "Emergency note text"

def test_memory_grounded_qa(temp_db):
    """Verify memory answerer answers strictly from memory context."""
    answerer = MemoryAnswerer(MockLocalLLMEngine())
    
    # Empty memories test
    empty_ans = answerer.answer_question("What do I need to carry?", [])
    assert "I couldn't find anything relevant in your memories." in empty_ans
