"""
MindBurst — Main Application Entrypoint
Polished offline-first personal memory app with Kivy/KivyMD, SQLite & Local LLM abstraction.
"""
import sys
import os

# Ensure project root is in sys.path regardless of execution working directory
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from kivymd.app import MDApp
from kivymd.uix.screenmanager import MDScreenManager
from kivymd.uix.boxlayout import MDBoxLayout
from kivy.core.window import Window

from mindburst.ui.theme.theme_config import ThemeConfig

from mindburst.ui.components.nav_bar import MindBurstNavBar
from mindburst.ui.screens.burst_screen import BurstScreen
from mindburst.ui.screens.understanding_screen import UnderstandingScreen
from mindburst.ui.screens.all_screen import AllScreen
from mindburst.ui.screens.memory_detail_screen import MemoryDetailScreen
from mindburst.ui.screens.ask_screen import AskScreen
from mindburst.ui.screens.recently_deleted_screen import RecentlyDeletedScreen


from mindburst.database.database import DatabaseManager
from mindburst.core.capture_service import CaptureService
from mindburst.core.extraction_service import ExtractionService
from mindburst.core.memory_service import MemoryService
from mindburst.core.search_service import SearchService
from mindburst.ai.memory_answerer import MemoryAnswerer
from mindburst.database.models import Memory
from typing import List, Dict, Optional

# Configure desktop window size for Android phone proportion preview
if "ANDROID_ARGUMENT" not in os.environ and not hasattr(sys, "getandroidapilevel"):
    Window.size = (380, 680)

class MindBurstApp(MDApp):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.title = "MindBurst"
        
        # Initialize SQLite & Services
        self.db = DatabaseManager.get_instance()
        self.capture_service = CaptureService()
        self.extraction_service = ExtractionService()
        self.memory_service = MemoryService()
        self.search_service = SearchService()
        self.memory_answerer = MemoryAnswerer()

        self.current_capture = None
        self.current_candidate_memories: List[Memory] = []

    def build(self):
        # Configure Theme (Golden-White Light Palette)
        self.theme_cls.theme_style = "Light"


        # Main Root Layout (Screen Container + Bottom Nav Bar)
        self.root_layout = MDBoxLayout(orientation="vertical")

        # Screen Manager
        self.screen_manager = MDScreenManager()

        # Build Screens
        self.burst_screen = BurstScreen(
            name="burst",
            on_burst_submit=self.handle_burst_capture,
            on_voice_submit=self.handle_voice_capture
        )
        self.understanding_screen = UnderstandingScreen(
            name="understanding",
            on_save_cb=self.handle_save_memories,
            on_cancel_cb=self.handle_cancel_capture
        )
        self.all_screen = AllScreen(
            name="all",
            on_select_memory_cb=self.handle_select_memory,
            on_filter_change_cb=self.handle_filter_change,
            on_burst_navigate_cb=self.navigate_to_burst,
            on_deleted_navigate_cb=self.navigate_to_deleted
        )
        self.memory_detail_screen = MemoryDetailScreen(
            name="detail",
            on_complete_cb=self.handle_complete_memory,
            on_save_edit_cb=self.handle_save_edited_memory,
            on_delete_cb=self.handle_delete_memory,
            on_back_cb=self.navigate_to_all
        )
        self.recently_deleted_screen = RecentlyDeletedScreen(
            name="deleted",
            on_restore_cb=self.handle_restore_memory,
            on_delete_forever_cb=self.handle_delete_forever_memory,
            on_back_cb=self.navigate_to_all
        )
        self.ask_screen = AskScreen(
            name="ask",
            on_ask_submit=self.handle_ask_question
        )

        self.screen_manager.add_widget(self.burst_screen)
        self.screen_manager.add_widget(self.understanding_screen)
        self.screen_manager.add_widget(self.all_screen)
        self.screen_manager.add_widget(self.memory_detail_screen)
        self.screen_manager.add_widget(self.recently_deleted_screen)
        self.screen_manager.add_widget(self.ask_screen)

        self.root_layout.add_widget(self.screen_manager)

        # Bottom Navigation Bar
        self.nav_bar = MindBurstNavBar(on_tab_switch_callback=self.on_nav_tab_switch)
        self.root_layout.add_widget(self.nav_bar)

        # Refresh initial data
        self.refresh_active_memories()

        return self.root_layout

    def on_nav_tab_switch(self, tab_id: str):
        if tab_id == "burst":
            self.screen_manager.current = "burst"
        elif tab_id == "all":
            self.refresh_active_memories()
            self.screen_manager.current = "all"
        elif tab_id == "ask":
            self.screen_manager.current = "ask"

    def handle_burst_capture(self, raw_text: str):
        """Phase 3 Capture Flow: Text input -> Capture -> AI Extraction -> Understanding Screen."""
        if not raw_text or not raw_text.strip():
            return

        capture = self.capture_service.capture_thought(raw_text, input_source="text")
        self.current_capture = capture
        extracted = self.extraction_service.extract_memories(capture)
        self.current_candidate_memories = extracted

        # Update Understanding screen & navigate
        self.understanding_screen.set_data(
            original_text=capture.original_text,
            extracted_memories=extracted
        )
        self.screen_manager.current = "understanding"

    def handle_voice_capture(self, raw_text: str):
        """Phase 11 Voice Capture Flow: Speech input -> Capture (input_source='voice') -> AI Extraction -> Understanding Screen."""
        if not raw_text or not raw_text.strip():
            return

        capture = self.capture_service.capture_thought(raw_text, input_source="voice")
        self.current_capture = capture
        extracted = self.extraction_service.extract_memories(capture)
        self.current_candidate_memories = extracted

        # Update Understanding screen & navigate
        self.understanding_screen.set_data(
            original_text=capture.original_text,
            extracted_memories=extracted
        )
        self.screen_manager.current = "understanding"


    def handle_save_memories(self, memories: List[Memory]):
        """Saves user-confirmed memories into SQLite database and updates All Screen."""
        self.memory_service.save_memories(memories)
        self.current_capture = None
        self.current_candidate_memories = []
        self.refresh_active_memories()
        self.nav_bar.set_active("all")
        self.screen_manager.current = "all"

    def handle_cancel_capture(self):
        """Cleanly rolls back uncommitted capture on cancel without orphaned data."""
        if self.current_capture and self.current_capture.id:
            self.capture_service.delete_capture(self.current_capture.id)
        self.current_capture = None
        self.current_candidate_memories = []
        self.nav_bar.set_active("burst")
        self.screen_manager.current = "burst"

    def refresh_active_memories(self):
        active = self.memory_service.get_active_memories()
        self.all_screen.set_memories(active)

    def handle_filter_change(self, filter_state: Dict[str, Optional[str]]):
        """Handles multi-field filter dispatch from AllScreen."""
        results = self.search_service.search_memories(
            query=filter_state.get("query"),
            category=filter_state.get("category"),
            retention=filter_state.get("retention"),
            start_date=filter_state.get("start_date"),
            end_date=filter_state.get("end_date")
        )
        self.all_screen.set_memories(results)

    def handle_select_memory(self, memory: Memory):
        """Navigates to MemoryDetailScreen for selected memory."""
        self.memory_detail_screen.set_memory(memory)
        self.screen_manager.current = "detail"

    def handle_save_edited_memory(self, memory: Memory):
        """Persists updated memory fields to SQLite database via MemoryService."""
        self.memory_service.update_memory(memory)
        self.refresh_active_memories()

    def handle_complete_memory(self, memory: Memory):
        if memory.id:
            self.memory_service.toggle_completion(memory.id)
            self.refresh_active_memories()
            self.screen_manager.current = "all"

    def handle_delete_memory(self, memory: Memory):
        if memory.id:
            self.memory_service.soft_delete_memory(memory.id)
            self.refresh_active_memories()
            self.screen_manager.current = "all"

    def handle_restore_memory(self, memory: Memory):
        if memory.id:
            self.memory_service.restore_memory(memory.id)
            deleted = self.memory_service.get_deleted_memories()
            self.recently_deleted_screen.set_deleted_memories(deleted)
            self.refresh_active_memories()

    def handle_delete_forever_memory(self, memory: Memory):
        if memory.id:
            self.memory_service.delete_forever(memory.id)
            deleted = self.memory_service.get_deleted_memories()
            self.recently_deleted_screen.set_deleted_memories(deleted)
            self.refresh_active_memories()

    def handle_ask_question(self, question: str):
        retrieved = self.search_service.search_memories(question, limit=10)
        answer = self.memory_answerer.answer_question(question, retrieved)
        self.ask_screen.set_answer(answer)

    def navigate_to_burst(self):
        self.nav_bar.set_active("burst")
        self.screen_manager.current = "burst"

    def navigate_to_all(self):
        self.nav_bar.set_active("all")
        self.screen_manager.current = "all"

    def navigate_to_deleted(self):
        deleted = self.memory_service.get_deleted_memories()
        self.recently_deleted_screen.set_deleted_memories(deleted)
        self.screen_manager.current = "deleted"


def main():
    MindBurstApp().run()

if __name__ == "__main__":
    main()

