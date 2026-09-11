"""
Phase 7 Automated Test Suite — All / Memory Browser + Search + Filters
"""
import tempfile
import os
import pytest
from datetime import datetime, timedelta
from kivymd.app import MDApp
from mindburst.database.database import DatabaseManager
from mindburst.database.repositories import CaptureRepository, MemoryRepository
from mindburst.database.models import Capture, Memory
from mindburst.core.capture_service import CaptureService
from mindburst.core.memory_service import MemoryService
from mindburst.core.search_service import SearchService
from mindburst.utils.date_normalizer import DateNormalizer
from mindburst.ui.screens.all_screen import AllScreen


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


def test_all_memories_load_newest_first(db_mgr):
    """Verify list_active_memories loads memories in chronological order with newest first."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)

    c1 = capture_repo.create_capture("First capture")
    c2 = capture_repo.create_capture("Second capture")

    m1 = Memory(capture_id=c1.id, type="Task", title="First Memory", category="Tasks")
    m2 = Memory(capture_id=c2.id, type="Task", title="Second Memory", category="Tasks")

    memory_service.save_memories([m1])
    memory_service.save_memories([m2])

    active = memory_service.get_active_memories()
    assert len(active) == 2
    assert active[0].title == "Second Memory"
    assert active[1].title == "First Memory"


def test_search_by_title(db_mgr):
    """Verify search finds memory matching title query."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)

    c = capture_repo.create_capture("Take laptop charger and ID")
    m = Memory(capture_id=c.id, type="Carry", title="Take charger and ID", category="Carry", items=["Charger", "ID"])
    memory_service.save_memories([m])

    res = search_service.search_memories(query="charger")
    assert len(res) == 1
    assert res[0].title == "Take charger and ID"


def test_search_by_original_text(db_mgr):
    """Verify search matches against captured original text."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)

    c = capture_repo.create_capture("Naalaiku college pogumbothu charger eduthutu poganum.")
    m = Memory(capture_id=c.id, type="Carry", title="Take charger", category="Carry")
    memory_service.save_memories([m])

    res = search_service.search_memories(query="naalaiku")
    assert len(res) == 1
    assert res[0].title == "Take charger"


def test_search_by_category(db_mgr):
    """Verify search matches against category string."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)

    c = capture_repo.create_capture("Maybe offline AI search")
    m = Memory(capture_id=c.id, type="Idea", title="Add offline AI search", category="Ideas")
    memory_service.save_memories([m])

    res = search_service.search_memories(query="Ideas")
    assert len(res) == 1
    assert res[0].category == "Ideas"


def test_search_by_people_items_projects(db_mgr):
    """Verify search matches against entity names (people, items, projects)."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)

    c = capture_repo.create_capture("Call Rahul about the JeevanSetu project")
    m = Memory(capture_id=c.id, type="Task", title="Call Rahul", category="Tasks", people=["Rahul"], projects=["JeevanSetu"])
    memory_service.save_memories([m])

    res_person = search_service.search_memories(query="Rahul")
    assert len(res_person) == 1

    res_project = search_service.search_memories(query="JeevanSetu")
    assert len(res_project) == 1


def test_today_date_filter(db_mgr):
    """Verify filtering by Today returns memories matching today's date."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)

    today_iso = datetime.now().strftime("%Y-%m-%d")
    tomorrow_iso = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")

    c = capture_repo.create_capture("Buy milk today")
    m_today = Memory(capture_id=c.id, type="Shopping", title="Buy milk", category="Shopping", date=today_iso)
    m_tomorrow = Memory(capture_id=c.id, type="Carry", title="Take charger", category="Carry", date=tomorrow_iso)
    memory_service.save_memories([m_today, m_tomorrow])

    s_start, s_end = DateNormalizer.get_date_range_for_filter("Today")
    res = search_service.search_memories(start_date=s_start, end_date=s_end)
    assert len(res) == 1
    assert res[0].title == "Buy milk"


def test_yesterday_date_filter(db_mgr):
    """Verify filtering by Yesterday returns memories matching yesterday's date."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)

    yesterday_iso = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
    c = capture_repo.create_capture("Note yesterday")
    m_yesterday = Memory(capture_id=c.id, type="Note", title="Past Note", category="Notes", date=yesterday_iso)
    memory_service.save_memories([m_yesterday])

    s_start, s_end = DateNormalizer.get_date_range_for_filter("Yesterday")
    res = search_service.search_memories(start_date=s_start, end_date=s_end)
    assert len(res) == 1
    assert res[0].title == "Past Note"


def test_this_week_date_filter():
    """Verify DateNormalizer returns valid start and end ISO dates for 'This week'."""
    s_start, s_end = DateNormalizer.get_date_range_for_filter("This week")
    assert s_start is not None
    assert s_end is not None
    assert s_start <= s_end


def test_category_filter(db_mgr):
    """Verify category filter narrows results to selected category only."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)

    c = capture_repo.create_capture("Test categories")
    m_carry = Memory(capture_id=c.id, type="Carry", title="Take ID", category="Carry")
    m_task = Memory(capture_id=c.id, type="Task", title="Call Rahul", category="Tasks")
    memory_service.save_memories([m_carry, m_task])

    res = search_service.search_memories(category="Carry")
    assert len(res) == 1
    assert res[0].category == "Carry"


def test_retention_filter(db_mgr):
    """Verify retention filter narrows results to specified retention mode."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)

    c = capture_repo.create_capture("Test retentions")
    m_temp = Memory(capture_id=c.id, type="Task", title="Temp Task", category="Tasks", retention="Temporary")
    m_perm = Memory(capture_id=c.id, type="Note", title="Permanent Note", category="Notes", retention="Permanent")
    memory_service.save_memories([m_temp, m_perm])

    res_perm = search_service.search_memories(retention="Permanent")
    assert len(res_perm) == 1
    assert res_perm[0].title == "Permanent Note"


def test_combined_filters(db_mgr):
    """Verify combining search, category, and retention filter rules."""
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)

    c = capture_repo.create_capture("Combined test")
    m1 = Memory(capture_id=c.id, type="Carry", title="Take charger and ID", category="Carry", retention="Temporary")
    m2 = Memory(capture_id=c.id, type="Carry", title="Take water bottle", category="Carry", retention="Keep Until Delete")
    m3 = Memory(capture_id=c.id, type="Task", title="Call Rahul charger", category="Tasks", retention="Temporary")
    memory_service.save_memories([m1, m2, m3])

    res = search_service.search_memories(query="charger", category="Carry", retention="Temporary")
    assert len(res) == 1
    assert res[0].title == "Take charger and ID"


def test_clear_reset_filters():
    """Verify reset_all_filters on AllScreen resets search and filter states to default."""
    screen = AllScreen()
    screen.search_field.text = "charger"
    screen.current_category_filter_idx = 1
    screen.current_retention_filter_idx = 1

    screen.reset_all_filters()

    assert screen.current_query == ""
    assert screen.search_field.text == ""
    assert screen.current_category_filter_idx == 0
    assert screen.current_retention_filter_idx == 0


def test_empty_state_rendering_and_navigation():
    """Verify empty state renders message and burst button when 0 memories are present."""
    nav_called = []
    screen = AllScreen(on_burst_navigate_cb=lambda: nav_called.append(True))
    screen.set_memories([])

    assert len(screen.memory_list.children) == 1
    screen._handle_burst_navigate()
    assert len(nav_called) == 1


def test_tapping_memory_triggers_detail_navigation_callback():
    """Verify tapping a memory row triggers on_select_memory_cb with the clicked memory."""
    selected = []
    screen = AllScreen(on_select_memory_cb=lambda m: selected.append(m))
    m = Memory(id=99, capture_id=1, type="Task", title="Selected Memory", category="Tasks")
    screen.set_memories([m])

    screen._handle_select_memory(m)
    assert len(selected) == 1
    assert selected[0].id == 99
