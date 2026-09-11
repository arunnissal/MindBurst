"""
Speech Recognition Service for MindBurst
Provides Android SpeechRecognizer bridge with desktop fallback simulation.
"""
from typing import Callable, Optional
import os
import sys

class SpeechService:
    def __init__(self):
        self.is_listening = False
        self._on_result_callback: Optional[Callable[[str], None]] = None
        self._on_error_callback: Optional[Callable[[str], None]] = None

    def is_available(self) -> bool:
        """Checks if speech recognition service is available."""
        if "ANDROID_ARGUMENT" in os.environ or hasattr(sys, "getandroidapilevel"):
            try:
                from jnius import autoclass # type: ignore
                SpeechRecognizer = autoclass('android.speech.SpeechRecognizer')
                PythonActivity = autoclass('org.kivy.android.PythonActivity')
                return SpeechRecognizer.isRecognitionAvailable(PythonActivity.mActivity)
            except Exception:
                return False
        return True # Available via desktop simulation mode

    def start_listening(
        self,
        on_result: Callable[[str], None],
        on_error: Callable[[str], None]
    ):
        """Starts speech recognition using Android API or desktop test fallback."""
        self.is_listening = True
        self._on_result_callback = on_result
        self._on_error_callback = on_error

        if "ANDROID_ARGUMENT" in os.environ or hasattr(sys, "getandroidapilevel"):
            self._start_android_speech()
        else:
            self._start_desktop_mock_speech()

    def stop_listening(self):
        """Stops active listening session."""
        self.is_listening = False

    def simulate_desktop_speech_result(self, text: str):
        """Simulates successful speech recognition result on desktop for testing."""
        self.is_listening = False
        if self._on_result_callback:
            self._on_result_callback(text)

    def simulate_desktop_speech_error(self, error_msg: str):
        """Simulates speech recognition error on desktop for testing."""
        self.is_listening = False
        if self._on_error_callback:
            self._on_error_callback(error_msg)

    def _start_desktop_mock_speech(self):
        """Simulates speech recognition on desktop for testing."""
        print("[SpeechService] Desktop speech simulation active.")

    def _start_android_speech(self):
        """Android Java SpeechRecognizer interface using pyjnius."""
        try:
            # Request RECORD_AUDIO permission at runtime safely
            try:
                from android.permissions import request_permissions, Permission # type: ignore
                request_permissions([Permission.RECORD_AUDIO])
            except Exception:
                pass

            from jnius import autoclass, PythonJavaClass, java_method # type: ignore
            # SpeechRecognizer Android bindings
            PythonActivity = autoclass('org.kivy.android.PythonActivity')

            Intent = autoclass('android.content.Intent')
            RecognizerIntent = autoclass('android.speech.RecognizerIntent')
            SpeechRecognizer = autoclass('android.speech.SpeechRecognizer')
            
            activity = PythonActivity.mActivity

            if not SpeechRecognizer.isRecognitionAvailable(activity):
                if self._on_error_callback:
                    self._on_error_callback("Speech recognition is not available on this device.")
                self.is_listening = False
                return

            intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)

            # Android SpeechListener proxy implementation
            class SpeechListener(PythonJavaClass):
                __javainterfaces__ = ['android/speech/RecognitionListener']

                def __init__(self, service):
                    super().__init__()
                    self.service = service

                @java_method('(Landroid/os/Bundle;)V')
                def onResults(self, results):
                    matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    if matches and matches.size() > 0:
                        text = matches.get(0)
                        if self.service._on_result_callback:
                            self.service._on_result_callback(str(text))
                    else:
                        if self.service._on_error_callback:
                            self.service._on_error_callback("No speech detected.")
                    self.service.is_listening = False

                @java_method('(I)V')
                def onError(self, error_code):
                    err_msg = f"Speech recognition error (code {error_code})"
                    if error_code == 7: # ERROR_NO_MATCH
                        err_msg = "No speech recognized. Please try speaking again."
                    elif error_code == 9: # ERROR_INSUFFICIENT_PERMISSIONS
                        err_msg = "Microphone permission denied."
                    
                    if self.service._on_error_callback:
                        self.service._on_error_callback(err_msg)
                    self.service.is_listening = False

                @java_method('(Landroid/os/Bundle;)V')
                def onReadyForSpeech(self, params): pass
                @java_method('()V')
                def onBeginningOfSpeech(self): pass
                @java_method('([B)V')
                def onRmsChanged(self, rms): pass
                @java_method('([B)V')
                def onBufferReceived(self, buffer): pass
                @java_method('()V')
                def onEndOfSpeech(self): pass
                @java_method('(ILandroid/os/Bundle;)V')
                def onEvent(self, event_type, params): pass
                @java_method('(ILandroid/os/Bundle;)V')
                def onPartialResults(self, partial_results): pass

            recognizer = SpeechRecognizer.createSpeechRecognizer(activity)
            listener = SpeechListener(self)
            recognizer.setRecognitionListener(listener)
            recognizer.startListening(intent)

        except Exception as e:
            if self._on_error_callback:
                self._on_error_callback(f"Speech recognition error: {e}")
            self.is_listening = False
