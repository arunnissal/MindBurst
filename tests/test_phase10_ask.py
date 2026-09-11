"""
Phase 10 Automated Test Suite — Ask / Grounded Local Memory Q&A
"""
import tempfile
import os
import pytest
from unittest.mock import MagicMock
from kivymd.app import MDApp
from mindburst.database.database import DatabaseManager
from mindburst.database.repositories import CaptureRepository, MemoryRepository
from mindburst.database.models import Memory
from mindburst.core.memory_service import MemoryService
from mindburst.core.search_service import SearchService
from mindburst.ai.memory_answerer import MemoryAnswerer
from mindburst.ai.llm_engine import MockLocalLLMEngine


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


def test_ask_with_matching_memory(db_mgr):
    """Verify asking with matching memory returns grounded answer."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)
    answerer = MemoryAnswerer(llm_engine=MockLocalLLMEngine())

    c = capture_repo.create_capture("Tomorrow college, take laptop charger and ID")
    m = Memory(capture_id=c.id, type="Carry", title="Take charger and ID", category="Carry", items=["Charger", "ID"], places=["College"])
    memory_service.save_memories([m])

    retrieved = search_service.search_memories(query="charger")
    answer = answerer.answer_question("What do I need to carry tomorrow?", retrieved)

    assert "charger" in answer.lower()
    assert "ID" in answer or "id" in answer.lower()


def test_answer_uses_retrieved_memory(db_mgr):
    """Verify MemoryAnswerer formats retrieved memory into context string for engine."""
    mock_llm = MagicMock()
    mock_llm.generate.return_value = "Grounded response using memory"
    answerer = MemoryAnswerer(llm_engine=mock_llm)

    m = Memory(id=1, capture_id=1, type="Task", title="Ask Rahul about project", category="Tasks", people=["Rahul"])
    answer = answerer.answer_question("What did I save about Rahul?", [m])

    assert answer == "Grounded response using memory"
    assert mock_llm.generate.called
    prompt_used = mock_llm.generate.call_args[0][0]
    assert "Ask Rahul about project" in prompt_used


def test_search_across_entities(db_mgr):
    """Verify search finds memories matching people, items, places, and projects."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)

    c = capture_repo.create_capture("Call Rahul about the JeevanSetu project at college")
    m = Memory(
        capture_id=c.id,
        type="Task",
        title="Call Rahul about project",
        category="Tasks",
        people=["Rahul"],
        places=["College"],
        projects=["JeevanSetu"]
    )
    memory_service.save_memories([m])

    assert len(search_service.search_memories(query="Rahul")) == 1
    assert len(search_service.search_memories(query="JeevanSetu")) == 1
    assert len(search_service.search_memories(query="College")) == 1


def test_no_result_question(db_mgr):
    """Verify question with 0 matching memories returns insufficient evidence message."""
    memory_repo = MemoryRepository(db_mgr)
    search_service = SearchService(memory_repo)
    answerer = MemoryAnswerer(llm_engine=MockLocalLLMEngine())

    retrieved = search_service.search_memories(query="Quantum Physics")
    answer = answerer.answer_question("Tell me about Quantum Physics", retrieved)

    assert answer == "I couldn't find anything relevant in your memories."


def test_no_result_does_not_call_llm():
    """Verify LLM generate() is NOT called when retrieved_memories list is empty."""
    mock_llm = MagicMock()
    answerer = MemoryAnswerer(llm_engine=mock_llm)

    res = answerer.answer_question("Where is my key?", [])

    assert res == "I couldn't find anything relevant in your memories."
    assert not mock_llm.generate.called


def test_prevent_unsupported_general_knowledge_answers():
    """Verify grounding prompt explicitly instructs engine to reject outside knowledge."""
    from mindburst.ai.prompt_manager import ANSWERING_SYSTEM_PROMPT
    assert "Use ONLY the supplied memories" in ANSWERING_SYSTEM_PROMPT
    assert "Do not use outside knowledge" in ANSWERING_SYSTEM_PROMPT
    assert "I couldn't find anything relevant in your memories." in ANSWERING_SYSTEM_PROMPT


def test_multiple_relevant_memories(db_mgr):
    """Verify multiple matching memories are included in context prompt."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)
    
    mock_llm = MagicMock()
    mock_llm.generate.return_value = "Combined answer"
    answerer = MemoryAnswerer(llm_engine=mock_llm)

    c = capture_repo.create_capture("Carry items test")
    m1 = Memory(capture_id=c.id, type="Carry", title="Take charger", category="Carry", items=["Charger"])
    m2 = Memory(capture_id=c.id, type="Carry", title="Take ID", category="Carry", items=["ID"])
    memory_service.save_memories([m1, m2])

    retrieved = search_service.search_memories(query="Take")
    answerer.answer_question("What do I carry?", retrieved)

    assert mock_llm.generate.called
    prompt_used = mock_llm.generate.call_args[0][0]
    assert "Take charger" in prompt_used
    assert "Take ID" in prompt_used


def test_date_related_question(db_mgr):
    """Verify date-related question returns relevant scheduled items."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)
    answerer = MemoryAnswerer(llm_engine=MockLocalLLMEngine())

    c = capture_repo.create_capture("Tomorrow college, take charger and ID")
    m = Memory(capture_id=c.id, type="Carry", title="Take charger and ID", category="Carry", date="Tomorrow", items=["Charger", "ID"])
    memory_service.save_memories([m])

    retrieved = search_service.search_memories(query="charger")
    answer = answerer.answer_question("What do I need to carry tomorrow?", retrieved)
    assert "charger" in answer.lower()


def test_project_person_question(db_mgr):
    """Verify person/project question returns grounded answer."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)
    answerer = MemoryAnswerer(llm_engine=MockLocalLLMEngine())

    c = capture_repo.create_capture("Ask Rahul about project")
    m = Memory(capture_id=c.id, type="Task", title="Ask Rahul about project", category="Tasks", people=["Rahul"])
    memory_service.save_memories([m])

    retrieved = search_service.search_memories(query="Rahul")
    answer = answerer.answer_question("What did I save about Rahul?", retrieved)
    assert "Rahul" in answer or "rahul" in answer.lower()


def test_gui_initialization():
    """Verify MindBurstApp initializes with AskScreen and Q&A engine."""
    from mindburst.main import MindBurstApp
    app = MindBurstApp()
    assert app.title == "MindBurst"
