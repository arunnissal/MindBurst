"""
Manual Scenarios Verification Script for Phase 6
Tests scenarios A, B, C, D, and E specified in prompt requirements.
"""
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from mindburst.core.extraction_service import ExtractionService
from mindburst.core.capture_service import CaptureService
from mindburst.database.models import Capture, Memory
from mindburst.utils.date_normalizer import DateNormalizer
from mindburst.ui.screens.understanding_screen import UnderstandingScreen, MemoryCardItem
from kivymd.app import MDApp

def run_verifications():
    print("=== MindBurst Phase 6 Manual Verification Scenarios ===")
    
    app = MDApp()
    app._run_prepare()
    
    svc = ExtractionService()
    
    # Scenario A — Compound thought
    cA = Capture(id=1, original_text="Tomorrow college, take laptop charger and ID, and remind me to ask Rahul about project.")
    mA = svc.extract_memories(cA)
    print("\nScenario A Output:")
    for m in mA:
        print(f"  [{m.type}] Title: {m.title} | Cat: {m.category} | Date: {m.date} | People: {m.people} | Places: {m.places} | Items: {m.items} | Projects: {m.projects}")
    assert any(m.type == "Carry" for m in mA)
    assert any(m.type == "Task" for m in mA)
    assert all(m.projects == [] for m in mA), "Generic project noise must NOT become entity"

    # Scenario B — Tanglish
    cB = Capture(id=2, original_text="Naalaiku college pogumbothu charger eduthutu poganum.")
    mB = svc.extract_memories(cB)
    print("\nScenario B Output:")
    for m in mB:
        print(f"  [{m.type}] Title: {m.title} | Cat: {m.category} | Date: {m.date} | Places: {m.places} | Items: {m.items}")
    assert mB[0].type == "Carry"
    assert "College" in mB[0].places

    # Scenario C — Named project
    cC = Capture(id=3, original_text="Call Rahul about the MindBurst project.")
    mC = svc.extract_memories(cC)
    print("\nScenario C Output:")
    print(f"  [{mC[0].type}] Title: {mC[0].title} | People: {mC[0].people} | Projects: {mC[0].projects}")
    assert mC[0].projects == ["MindBurst"]

    # Scenario D — Generic project
    cD = Capture(id=4, original_text="Call Rahul about the project.")
    mD = svc.extract_memories(cD)
    print("\nScenario D Output:")
    print(f"  [{mD[0].type}] Title: {mD[0].title} | People: {mD[0].people} | Projects: {mD[0].projects}")
    assert mD[0].projects == []

    # Scenario E — Fallback Note
    fallback_note = Memory(capture_id=5, type="Note", title="Original thought preserved exactly", details="Original thought preserved exactly", category="Notes", retention="Temporary")
    screenE = UnderstandingScreen(original_text="Original thought preserved exactly", extracted_memories=[fallback_note])
    print("\nScenario E Output:")
    print(f"  Fallback card rendered title: {screenE.card_widgets[0].title_field.text}")
    assert screenE.card_widgets[0].title_field.text == "Original thought preserved exactly"

    print("\n[OK] ALL PHASE 6 SCENARIOS VERIFIED SUCCESSFULLY!")

if __name__ == "__main__":
    run_verifications()
