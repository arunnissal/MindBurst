"""
Manual Scenario Verification Script for Phase 3
Verifies:
1. Input: "Tomorrow college, take laptop charger and ID, and remind me to ask Rahul about project."
2. AI Extraction output (Carry + Task)
3. Editing an extracted field
4. Save flow
5. Querying All screen feed
6. Search for "Rahul"
7. App restart / persistence verification
"""
import os
import tempfile
from mindburst.database.database import DatabaseManager
from mindburst.database.repositories import CaptureRepository, MemoryRepository
from mindburst.core.capture_service import CaptureService
from mindburst.core.extraction_service import ExtractionService
from mindburst.core.memory_service import MemoryService
from mindburst.core.search_service import SearchService
from mindburst.ai.llm_engine import MockLocalLLMEngine

def run_verification():
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        db_path = f.name

    try:
        db = DatabaseManager(db_path=db_path)
        capture_service = CaptureService(CaptureRepository(db))
        extraction_service = ExtractionService(MockLocalLLMEngine())
        memory_service = MemoryService(MemoryRepository(db))
        search_service = SearchService(MemoryRepository(db))

        # 1. User Input
        user_input = "Tomorrow college, take laptop charger and ID, and remind me to ask Rahul about project."
        print(f"1. Input: '{user_input}'")

        # 2. Capture & Extraction
        capture = capture_service.capture_thought(user_input, input_source="text")
        memories = extraction_service.extract_memories(capture)
        print(f"2. Extracted {len(memories)} memories:")
        for idx, m in enumerate(memories, 1):
            print(f"   Memory {idx}: Type={m.type}, Title='{m.title}', Category={m.category}, Date={m.date}")

        # 3. Edit one extracted field (Simulate User Editing on Understanding Screen)
        memories[0].title = "Edited: Carry Laptop Charger & ID"
        print(f"3. Simulated User Edit -> Memory 1 Title set to: '{memories[0].title}'")

        # 4. Save
        saved = memory_service.save_memories(memories)
        print(f"4. Saved {len(saved)} memories to SQLite.")

        # 5. Query All screen memories
        active = memory_service.get_active_memories()
        print(f"5. All Screen Active Memories Feed Count: {len(active)}")
        for m in active:
            print(f"   - '{m.title}' [{m.category}]")

        # 6. Search for "Rahul"
        rahul_results = search_service.search_memories("Rahul")
        print(f"6. Search for 'Rahul' returned {len(rahul_results)} result(s):")
        for r in rahul_results:
            print(f"   - '{r.title}' (People: {r.people})")

        # 7. Restart Application / DB Connection test
        print("7. Simulating App Restart (re-opening SQLite database file)...")
        db_restart = DatabaseManager(db_path=db_path)
        mem_service_restart = MemoryService(MemoryRepository(db_restart))
        persisted_memories = mem_service_restart.get_active_memories()
        print(f"   Post-restart active memory count: {len(persisted_memories)}")
        assert len(persisted_memories) == len(saved)
        print("[OK] All Phase 3 Scenario Checks PASSED!")


    finally:
        if os.path.exists(db_path):
            os.remove(db_path)

if __name__ == "__main__":
    run_verification()
