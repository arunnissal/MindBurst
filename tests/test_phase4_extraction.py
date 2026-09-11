"""
Phase 4 Automated Test Suite — Extraction Intelligence & Quality
Tests 15 mandatory natural language/Tanglish semantic extraction test cases,
date normalization, controlled enum enforcement, deduplication, time preservation,
and graceful fallback handling.
"""
from datetime import datetime, timedelta
import pytest

from mindburst.database.models import Capture
from mindburst.core.extraction_service import ExtractionService
from mindburst.ai.llm_engine import MockLocalLLMEngine
from mindburst.ai.extraction_parser import ExtractionParser
from mindburst.utils.date_normalizer import DateNormalizer

@pytest.fixture
def extraction_service():
    return ExtractionService(MockLocalLLMEngine())

def test_date_normalizer():
    """Verify relative date expressions resolve to canonical YYYY-MM-DD strings."""
    ref_date = datetime(2026, 9, 3) # Thursday
    
    assert DateNormalizer.resolve_date("Today", ref_date) == "2026-09-03"
    assert DateNormalizer.resolve_date("Tomorrow", ref_date) == "2026-09-04"
    assert DateNormalizer.resolve_date("Yesterday", ref_date) == "2026-09-02"
    assert DateNormalizer.resolve_date("naalaiku", ref_date) == "2026-09-04"
    assert DateNormalizer.resolve_date("2026-10-15", ref_date) == "2026-10-15"
    assert DateNormalizer.resolve_date("this Friday", ref_date) == "2026-09-04"
    assert DateNormalizer.resolve_date("next Monday", ref_date) == "2026-09-07"


def test_case_1_project_name(extraction_service):
    c = Capture(id=1, original_text="My project name is MindBurst.")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 1
    assert "MindBurst" in memories[0].projects or "MindBurst" in memories[0].title


def test_case_2_submit_assignment(extraction_service):
    c = Capture(id=2, original_text="Tomorrow I need to submit the assignment.")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 1
    assert memories[0].type == "Task"
    assert memories[0].date == (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")


def test_case_3_take_charger_and_id(extraction_service):
    c = Capture(id=3, original_text="Take my charger and ID when I go to college tomorrow.")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 1
    assert memories[0].type == "Carry"
    assert "Charger" in memories[0].items or "ID" in memories[0].items
    assert "College" in memories[0].places


def test_case_4_buy_milk_call_mom_send_doc(extraction_service):
    c = Capture(id=4, original_text="Buy milk, call mom and send the project document.")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 3
    types = [m.type for m in memories]
    assert "Shopping" in types
    assert "Task" in types


def test_case_5_ask_rahul_database(extraction_service):
    c = Capture(id=5, original_text="Ask Rahul about the database tomorrow.")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 1
    assert memories[0].type == "Task"
    assert "Rahul" in memories[0].people


def test_case_6_jeevansetu_before_friday(extraction_service):
    c = Capture(id=6, original_text="I should finish the JeevanSetu documentation before Friday.")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 1
    assert "JeevanSetu" in memories[0].projects or "JeevanSetu" in memories[0].title


def test_case_7_offline_ai_search(extraction_service):
    c = Capture(id=7, original_text="Maybe we can add offline AI search to MindBurst.")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 1
    assert memories[0].type == "Idea"
    assert "MindBurst" in memories[0].projects or "MindBurst" in memories[0].title


def test_case_8_buy_notebook_college(extraction_service):
    c = Capture(id=8, original_text="When coming back from college, buy a new notebook.")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 1
    assert memories[0].type == "Shopping"
    assert "Notebook" in memories[0].items or "notebook" in memories[0].title.lower()


def test_case_9_carry_charger_id_headphones(extraction_service):
    c = Capture(id=9, original_text="I usually carry my charger, ID and headphones to college.")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 1
    assert memories[0].type == "Carry"
    assert "Charger" in memories[0].items or "ID" in memories[0].items or "Headphones" in memories[0].items


def test_case_10_power_bank_emoji(extraction_service):
    c = Capture(id=10, original_text="Oh yeah don't let me forget to take my power bank tomorrow 😂")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 1
    assert memories[0].type == "Carry"
    assert "Power bank" in memories[0].items or "power bank" in memories[0].title.lower()


def test_case_11_compound_remind_call_buy(extraction_service):
    c = Capture(id=11, original_text="Tomorrow after class, remind me to call Rahul about the project, and buy coffee on the way home.")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 2
    titles = [m.title.lower() for m in memories]
    assert any("rahul" in t or "project" in t for t in titles)
    assert any("coffee" in t for t in titles)


def test_case_12_github_student_account(extraction_service):
    c = Capture(id=12, original_text="I need to renew my GitHub student account.")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 1
    assert memories[0].type == "Task"


def test_case_13_work_on_that_project(extraction_service):
    c = Capture(id=13, original_text="I should probably work on that project.")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 1
    assert memories[0].type in ["Task", "Idea"]


def test_case_14_tanglish_charger(extraction_service):
    c = Capture(id=14, original_text="Naalaiku college pogumbothu charger eduthutu poganum.")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 1
    assert memories[0].type == "Carry"
    assert memories[0].date == (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")


def test_case_15_tanglish_charger_id(extraction_service):
    c = Capture(id=15, original_text="Tomorrow college poganum charger edukanum and uh id card don't forget")
    memories = extraction_service.extract_memories(c)
    assert len(memories) == 1
    assert memories[0].type == "Carry"
    assert "Charger" in memories[0].items or "ID card" in memories[0].items


def test_enum_validation_and_deduplication():
    """Verify enum bounds checking and deduplication."""
    invalid_json = '''{
      "memories": [
        {"type": "SUPER_ACTION", "title": "Test 1", "category": "UNKNOWN_CAT", "retention": "INVALID_RETENTION", "date": "Tomorrow"},
        {"type": "SUPER_ACTION", "title": "Test 1", "category": "UNKNOWN_CAT", "retention": "INVALID_RETENTION", "date": "Tomorrow"}
      ]
    }'''

    memories = ExtractionParser.parse_llm_response(invalid_json, capture_id=1, original_text="Sample input")
    assert len(memories) == 1 # Deduplicated
    assert memories[0].type == "Note" # Controlled fallback
    assert memories[0].category == "Notes" # Controlled fallback
    assert memories[0].retention == "Temporary" # Controlled fallback


def test_explicit_vs_generic_project_extraction(extraction_service):
    """Verify that generic 'the project' is not extracted as entity, but 'MindBurst' is."""
    c_explicit = Capture(id=101, original_text="Call Rahul about the MindBurst project.")
    m_explicit = extraction_service.extract_memories(c_explicit)
    assert len(m_explicit) == 1
    assert m_explicit[0].projects == ["MindBurst"]

    c_generic = Capture(id=102, original_text="Call Rahul about the project.")
    m_generic = extraction_service.extract_memories(c_generic)
    assert len(m_generic) == 1
    assert m_generic[0].projects == []


def test_generic_noise_words_not_extracted_as_entities():
    """Verify that generic words like 'the project', 'the assignment', 'a task', 'that thing' are filtered from entities."""
    json_with_noise = '''{
      "memories": [
        {
          "type": "Task",
          "title": "Call Rahul about project",
          "projects": ["the project", "MindBurst"],
          "items": ["that thing", "Laptop"],
          "people": ["someone", "Rahul"],
          "places": ["location", "Office"]
        }
      ]
    }'''
    memories = ExtractionParser.parse_llm_response(json_with_noise, capture_id=200, original_text="Sample input")
    assert len(memories) == 1
    assert memories[0].projects == ["MindBurst"]
    assert memories[0].items == ["Laptop"]
    assert memories[0].people == ["Rahul"]
    assert memories[0].places == ["Office"]


def test_malformed_json_fallback():
    """Verify completely broken LLM response defaults to single Note memory without crashing."""
    memories = ExtractionParser.parse_llm_response("NOT_VALID_JSON_AT_ALL", capture_id=100, original_text="Original unlost text")
    assert len(memories) == 1
    assert memories[0].type == "Note"
    assert memories[0].category == "Notes"
    assert memories[0].original_text == "Original unlost text"


