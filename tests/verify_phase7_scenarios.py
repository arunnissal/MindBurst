"""
Phase 7 Manual Verification Scenarios Runner
Executes Phase 7 end-to-end memory capture, browsing, search, date/category/retention filtering, and selection.
"""
import os
import tempfile
from kivymd.app import MDApp
from mindburst.database.database import DatabaseManager
from mindburst.database.repositories import CaptureRepository, MemoryRepository
from mindburst.core.capture_service import CaptureService
from mindburst.core.extraction_service import ExtractionService
from mindburst.core.memory_service import MemoryService
from mindburst.core.search_service import SearchService
from mindburst.utils.date_normalizer import DateNormalizer
from mindburst.ui.screens.all_screen import AllScreen
from mindburst.ui.screens.memory_detail_screen import MemoryDetailScreen


def run_phase7_verifications():
    print("=== MindBurst Phase 7 Manual Verification Scenarios ===")

    # Prepare KivyMD App Context
    app = MDApp()
    app._run_prepare()

    # Temporary SQLite DB

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        db_path = f.name

    db_mgr = DatabaseManager(db_path=db_path)
    capture_repo = CaptureRepository(db_mgr)
    memory_repo = MemoryRepository(db_mgr)
    capture_service = CaptureService(capture_repo)
    extraction_service = ExtractionService()
    memory_service = MemoryService(memory_repo)
    search_service = SearchService(memory_repo)

    # 1. Populate standard scenario memories
    thoughts = [
        "Tomorrow college, take laptop charger and ID, and remind me to ask Rahul about project.",
        "Buy milk tomorrow.",
        "Maybe we can add offline AI search to MindBurst.",
        "I usually carry my charger, ID and headphones to college.",
        "I should finish the JeevanSetu documentation before Friday."
    ]

    all_saved = []
    for text in thoughts:
        c = capture_service.capture_thought(text, input_source="text")
        extracted = extraction_service.extract_memories(c)
        saved = memory_service.save_memories(extracted)
        all_saved.extend(saved)

    print(f"\n[1. Feed Population] Saved {len(all_saved)} memories into SQLite.")

    # 2. Chronological All memories feed
    active = memory_service.get_active_memories()
    print(f"[2. All Feed] Total Active Memories: {len(active)}")
    assert len(active) >= 5, "Expected all memories in feed"

    # 3. Search Verifications
    res_charger = search_service.search_memories(query="charger")
    print(f"\n[3a. Search 'charger'] Found {len(res_charger)} memories:")
    for m in res_charger:
        print(f"  - [{m.type}] {m.title} (Items: {m.items})")
    assert len(res_charger) >= 2, "Expected at least 2 charger memories"

    res_rahul = search_service.search_memories(query="Rahul")
    print(f"\n[3b. Search 'Rahul'] Found {len(res_rahul)} memories:")
    for m in res_rahul:
        print(f"  - [{m.type}] {m.title} (People: {m.people})")
    assert any("Rahul" in m.people for m in res_rahul), "Expected Rahul task memory"

    res_jeevansetu = search_service.search_memories(query="JeevanSetu")
    print(f"\n[3c. Search 'JeevanSetu'] Found {len(res_jeevansetu)} memories:")
    for m in res_jeevansetu:
        print(f"  - [{m.type}] {m.title} (Projects: {m.projects})")
    assert any("JeevanSetu" in m.projects for m in res_jeevansetu), "Expected JeevanSetu documentation memory"

    # 4. Category Filter
    carry_mems = search_service.search_memories(category="Carry")
    print(f"\n[4. Category Filter 'Carry'] Found {len(carry_mems)} carry memories:")
    for m in carry_mems:
        print(f"  - [{m.category}] {m.title}")
    assert all(m.category == "Carry" for m in carry_mems)

    # 5. Retention Filter
    temp_mems = search_service.search_memories(retention="Temporary")
    print(f"\n[5. Retention Filter 'Temporary'] Found {len(temp_mems)} temporary memories.")
    assert len(temp_mems) == len(active)

    # 6. Date Filter
    s_start, s_end = DateNormalizer.get_date_range_for_filter("This week")
    week_mems = search_service.search_memories(start_date=s_start, end_date=s_end)
    print(f"\n[6. Date Filter 'This week'] Found {len(week_mems)} memories for this week.")

    # 7. Combined Filters
    combined = search_service.search_memories(query="charger", category="Carry", retention="Temporary")
    print(f"\n[7. Combined Filters 'charger' + 'Carry' + 'Temporary'] Found {len(combined)} memories:")
    for m in combined:
        print(f"  - [{m.type}] {m.title}")
    assert len(combined) >= 2

    # 8. AllScreen & MemoryDetailScreen interaction check
    selected_target = None
    def select_cb(mem):
        nonlocal selected_target
        selected_target = mem

    all_screen = AllScreen(on_select_memory_cb=select_cb)
    all_screen.set_memories(active)
    
    # Simulate tapping row 0
    all_screen._handle_select_memory(active[0])
    print(f"\n[8. Interaction] Selected memory row: '{selected_target.title}'")

    detail_screen = MemoryDetailScreen()
    detail_screen.set_memory(selected_target)
    print(f"[8. Detail Screen] Rendered detail for: '{detail_screen.memory.title}'")
    assert detail_screen.memory.title == selected_target.title

    db_mgr.close()
    if os.path.exists(db_path):
        try:
            os.remove(db_path)
        except PermissionError:
            pass

    print("\n[OK] ALL PHASE 7 SCENARIOS VERIFIED SUCCESSFULLY!")


if __name__ == "__main__":
    run_phase7_verifications()
