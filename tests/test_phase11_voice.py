"""
Phase 11 Automated Test Suite — Voice Capture (Speech Recognition & Input Source)
"""
import tempfile
import os
import pytest
from unittest.mock import MagicMock
from kivymd.app import MDApp
from mindburst.database.database import DatabaseManager
from mindburst.database.repositories import CaptureRepository, MemoryRepository
from mindburst.database.models import Capture
from mindburst.core.capture_service import CaptureService
from mindburst.core.memory_service import MemoryService
from mindburst.voice.speech_service import SpeechService
from mindburst.ui.screens.burst_screen import BurstScreen


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


def test_voice_button_starts_recognition():
    """Verify tapping microphone button starts speech recognition session."""
    mock_speech = MagicMock(spec=SpeechService)
    mock_speech.is_available.return_value = True

    screen = BurstScreen(speech_service=mock_speech)
    screen._toggle_voice_input()

    assert screen.is_listening is True
    assert mock_speech.start_listening.called


def test_recognized_text_reaches_capture_flow():
    """Verify recognized speech text is passed to on_voice_submit callback."""
    voice_results = []
    speech_service = SpeechService()
    screen = BurstScreen(
        on_voice_submit=lambda text: voice_results.append(text),
        speech_service=speech_service
    )

    screen._start_listening()
    speech_service.simulate_desktop_speech_result("Take laptop charger and ID to college")

    assert len(voice_results) == 1
    assert voice_results[0] == "Take laptop charger and ID to college"


def test_input_source_voice(db_mgr):
    """Verify voice captures are persisted into SQLite with input_source='voice'."""
    capture_repo = CaptureRepository(db_mgr)
    capture_service = CaptureService(capture_repo)

    c = capture_service.capture_thought("Spoken thought text", input_source="voice")
    
    assert c.input_source == "voice"
    persisted = capture_repo.get_capture_by_id(c.id)
    assert persisted is not None
    assert persisted.input_source == "voice"


def test_empty_speech_handled():
    """Verify empty speech recognition result displays warning without crashing."""
    speech_service = SpeechService()
    screen = BurstScreen(speech_service=speech_service)

    screen._start_listening()
    speech_service.simulate_desktop_speech_result("   ")

    assert "No speech detected" in screen.status_label.text


def test_recognition_failure_handled():
    """Verify speech recognition error displays error message without crashing."""
    speech_service = SpeechService()
    screen = BurstScreen(speech_service=speech_service)

    screen._start_listening()
    speech_service.simulate_desktop_speech_error("No speech recognized.")

    assert "No speech recognized" in screen.status_label.text
    assert screen.is_listening is False


def test_permission_unavailable_handled_safely():
    """Verify permission denied or unavailable speech recognition is handled safely."""
    mock_speech = MagicMock(spec=SpeechService)
    mock_speech.is_available.return_value = False

    screen = BurstScreen(speech_service=mock_speech)
    screen._toggle_voice_input()

    assert "unavailable" in screen.status_label.text.lower()
    assert screen.is_listening is False


def test_existing_text_capture_unchanged(db_mgr):
    """Verify text captures continue saving with input_source='text'."""
    capture_repo = CaptureRepository(db_mgr)
    capture_service = CaptureService(capture_repo)

    c = capture_service.capture_thought("Typed thought text", input_source="text")
    
    assert c.input_source == "text"
    persisted = capture_repo.get_capture_by_id(c.id)
    assert persisted is not None
    assert persisted.input_source == "text"


def test_gui_initialization():
    """Verify MindBurstApp initializes with voice integration intact."""
    from mindburst.main import MindBurstApp
    app = MindBurstApp()
    assert app.title == "MindBurst"
