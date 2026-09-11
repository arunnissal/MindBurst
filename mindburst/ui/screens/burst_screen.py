"""
Burst Screen — Instant Thought Capture (Text & Voice)
Golden-white palette with listening waveform indicator and graceful error handling.
"""
from typing import Callable, Optional
from kivymd.uix.screen import MDScreen
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.label import MDLabel
from kivymd.uix.button import MDButton, MDButtonText, MDIconButton
from kivymd.uix.textfield import MDTextField, MDTextFieldHintText
from kivymd.uix.card import MDCard
from kivy.graphics import Color, Rectangle
from kivy.clock import Clock

from mindburst.ui.theme.theme_config import ThemeConfig
from mindburst.voice.speech_service import SpeechService


class BurstScreen(MDScreen):
    def __init__(
        self,
        on_burst_submit: Optional[Callable[[str], None]] = None,
        on_voice_submit: Optional[Callable[[str], None]] = None,
        speech_service: Optional[SpeechService] = None,
        **kwargs
    ):
        super().__init__(**kwargs)
        self.on_burst_submit = on_burst_submit
        self.on_voice_submit = on_voice_submit
        self.speech_service = speech_service or SpeechService()
        self.is_listening = False
        self._pulse_event = None
        self._pulse_step = 0
        self._build_ui()

    def _build_ui(self):
        # Outer Layout
        layout = MDBoxLayout(
            orientation="vertical",
            padding=["24dp", "28dp", "24dp", "16dp"],
            spacing="16dp"
        )
        
        # Background
        with layout.canvas.before:
            Color(*ThemeConfig.BACKGROUND_COLOR)
            self.bg_rect = Rectangle(pos=layout.pos, size=layout.size)
        layout.bind(pos=self._update_bg, size=self._update_bg)

        # Header Title: MINDBURST ✦
        header = MDLabel(
            text="MINDBURST ✦",
            font_size="22sp",
            bold=True,
            halign="center",
            theme_text_color="Custom",
            text_color=ThemeConfig.GOLD_ACCENT,
            size_hint_y=None,
            height="36dp"
        )
        layout.add_widget(header)

        # Subtitle: What's on your mind?
        subtitle = MDLabel(
            text="What's on your mind?",
            font_size="15sp",
            halign="center",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_PRIMARY,
            size_hint_y=None,
            height="26dp"
        )
        layout.add_widget(subtitle)

        # Text Input Card
        input_card = MDCard(
            size_hint=(1.0, 0.45),
            padding="14dp",
            md_bg_color=ThemeConfig.CARD_BACKGROUND,
            radius=[16, 16, 16, 16]
        )
        
        self.text_input = MDTextField(
            multiline=True,
            mode="outlined",
            size_hint=(1.0, 1.0)
        )
        self.text_input.add_widget(
            MDTextFieldHintText(text="Type anything... task, carry item, shopping, idea, thought...")
        )
        input_card.add_widget(self.text_input)
        layout.add_widget(input_card)

        # Status / Pulsing Waveform indicator
        self.status_label = MDLabel(
            text="",
            font_size="13sp",
            halign="center",
            theme_text_color="Custom",
            text_color=ThemeConfig.GOLD_ACCENT,
            size_hint_y=None,
            height="24dp"
        )
        layout.add_widget(self.status_label)

        # Voice Microphone Section (Tap-to-Speak)
        voice_box = MDBoxLayout(
            orientation="vertical",
            size_hint_y=None,
            height="64dp"
        )
        self.mic_button = MDIconButton(
            icon="microphone",
            style="standard",
            theme_icon_color="Custom",
            icon_color=ThemeConfig.GOLD_ACCENT,
            size_hint=(None, None),
            size=("52dp", "52dp"),
            pos_hint={"center_x": 0.5}
        )
        self.mic_button.bind(on_release=self._toggle_voice_input)
        voice_box.add_widget(self.mic_button)
        layout.add_widget(voice_box)

        # 💥 Burst Action Button
        burst_btn = MDButton(
            style="elevated",
            pos_hint={"center_x": 0.5},
            size_hint=(0.8, None),
            height="48dp"
        )
        burst_btn.md_bg_color = ThemeConfig.GOLD_ACCENT
        burst_btn.add_widget(
            MDButtonText(
                text="💥 Burst",
                font_size="17sp",
                bold=True,
                theme_text_color="Custom",
                text_color=(1, 1, 1, 1)
            )
        )
        burst_btn.bind(on_release=self._handle_burst_click)
        layout.add_widget(burst_btn)

        self.add_widget(layout)

    def _update_bg(self, instance, value):
        self.bg_rect.pos = instance.pos
        self.bg_rect.size = instance.size

    def _toggle_voice_input(self, *args):
        """Toggles listening state and initiates speech recognition."""
        if not self.is_listening:
            self._start_listening()
        else:
            self._stop_listening()

    def _start_listening(self):
        if not self.speech_service.is_available():
            self.status_label.text = "Speech recognition is unavailable on this device."
            return

        self.is_listening = True
        self.status_label.text = "Listening… 🎙"
        self.mic_button.icon_color = (0.9, 0.2, 0.2, 1) # Red active pulse
        
        # Start waveform animation timer
        self._pulse_step = 0
        if self._pulse_event:
            self._pulse_event.cancel()
        self._pulse_event = Clock.schedule_interval(self._animate_listening_wave, 0.4)

        self.speech_service.start_listening(
            on_result=self._handle_speech_result,
            on_error=self._handle_speech_error
        )

    def _stop_listening(self):
        self.is_listening = False
        if self._pulse_event:
            self._pulse_event.cancel()
            self._pulse_event = None
        self.speech_service.stop_listening()
        self.status_label.text = ""
        self.mic_button.icon_color = ThemeConfig.GOLD_ACCENT

    def _animate_listening_wave(self, dt):
        if not self.is_listening:
            return False
        waves = ["Listening… 🎙  ▰▱▱", "Listening… 🎙  ▰▰▱", "Listening… 🎙  ▰▰▰", "Listening… 🎙  ▱▰▰"]
        self.status_label.text = waves[self._pulse_step % len(waves)]
        self._pulse_step += 1

    def _handle_speech_result(self, text: str):
        """Processes recognized speech text."""
        self._stop_listening()

        clean_text = text.strip() if text else ""
        if not clean_text:
            self.status_label.text = "No speech detected. Tap 🎙️ to try again."
            return

        self.status_label.text = "Understanding…"

        # Populate text input for transparency
        self.text_input.text = clean_text

        # Submit via voice callback or standard submit callback
        if self.on_voice_submit:
            self.on_voice_submit(clean_text)
        elif self.on_burst_submit:
            self.on_burst_submit(clean_text)

        # Reset status after short delay
        Clock.schedule_once(lambda dt: setattr(self, 'status_label.text', ''), 1.5)

    def _handle_speech_error(self, error_msg: str):
        """Handles speech recognition errors gracefully without crashing."""
        self._stop_listening()
        self.status_label.text = f"{error_msg} Tap 🎙️ to retry."

    def _handle_burst_click(self, *args):
        text = self.text_input.text.strip()
        if not text:
            self.status_label.text = "Please enter or speak a thought first!"
            return

        if self.on_burst_submit:
            self.on_burst_submit(text)
        
        # Reset input after submission
        self.text_input.text = ""
        self.status_label.text = ""
