"""
Ask Screen — Grounded Natural Language Memory Q&A
Query your private memories naturally without hallucination.
Aesthetic: Golden-white palette + compact clean response layout.
"""
from typing import Optional, Callable
from kivymd.uix.screen import MDScreen
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.label import MDLabel
from kivymd.uix.button import MDButton, MDButtonText
from kivymd.uix.textfield import MDTextField, MDTextFieldHintText
from kivymd.uix.card import MDCard
from kivymd.uix.scrollview import MDScrollView
from kivy.graphics import Color, Rectangle

from mindburst.ui.theme.theme_config import ThemeConfig


class AskScreen(MDScreen):
    def __init__(
        self,
        on_ask_submit: Optional[Callable[[str], None]] = None,
        **kwargs
    ):
        super().__init__(**kwargs)
        self.on_ask_submit = on_ask_submit
        self._build_ui()

    def set_answer(self, answer_text: str):
        """Displays answer in the compact response area."""
        self.answer_card.opacity = 1.0
        self.answer_label.text = answer_text

    def set_thinking_state(self):
        """Displays simple 'Thinking...' loading state."""
        self.answer_card.opacity = 1.0
        self.answer_label.text = "Thinking…"

    def _build_ui(self):
        layout = MDBoxLayout(
            orientation="vertical",
            padding=["20dp", "24dp", "20dp", "16dp"],
            spacing="14dp"
        )

        with layout.canvas.before:
            Color(*ThemeConfig.BACKGROUND_COLOR)
            self.bg_rect = Rectangle(pos=layout.pos, size=layout.size)
        layout.bind(pos=self._update_bg, size=self._update_bg)

        # Header Box: Ask your memory / Find something you remember.
        header_box = MDBoxLayout(orientation="vertical", spacing="2dp", size_hint_y=None, height="48dp")
        header_title = MDLabel(
            text="Ask your memory",
            font_size="22sp",
            bold=True,
            theme_text_color="Custom",
            text_color=ThemeConfig.GOLD_ACCENT,
            size_hint_y=None,
            height="28dp"
        )
        subtext = MDLabel(
            text="Find something you remember.",
            font_size="13sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_SECONDARY,
            size_hint_y=None,
            height="20dp"
        )
        header_box.add_widget(header_title)
        header_box.add_widget(subtext)
        layout.add_widget(header_box)

        # Query Input Card
        input_card = MDCard(
            size_hint=(1.0, None),
            height="72dp",
            padding="8dp",
            md_bg_color=ThemeConfig.CARD_BACKGROUND,
            radius=[12, 12, 12, 12]
        )
        self.query_field = MDTextField(
            mode="outlined",
            size_hint=(1.0, 1.0)
        )
        self.query_field.add_widget(
            MDTextFieldHintText(text="Ask something about your memories...")
        )
        input_card.add_widget(self.query_field)
        layout.add_widget(input_card)

        # Ask Action Button
        ask_btn = MDButton(
            style="elevated",
            pos_hint={"center_x": 0.5},
            size_hint=(0.8, None),
            height="46dp"
        )
        ask_btn.md_bg_color = ThemeConfig.GOLD_ACCENT
        ask_btn.add_widget(
            MDButtonText(
                text="Ask",
                font_size="15sp",
                bold=True,
                theme_text_color="Custom",
                text_color=(1, 1, 1, 1)
            )
        )
        ask_btn.bind(on_release=self._handle_ask_click)
        layout.add_widget(ask_btn)

        # Answer Result Card
        scroll = MDScrollView(size_hint=(1.0, 1.0))
        self.answer_card = MDCard(
            size_hint=(1.0, None),
            padding="16dp",
            md_bg_color=ThemeConfig.GOLD_ACCENT_LIGHT,
            radius=[12, 12, 12, 12],
            opacity=0.0
        )
        self.answer_card.bind(minimum_height=self.answer_card.setter("height"))

        box = MDBoxLayout(orientation="vertical", spacing="6dp", size_hint_y=None)
        box.bind(minimum_height=box.setter("height"))

        ans_header = MDLabel(
            text="MEMORY RESPONSE",
            font_size="11sp",
            bold=True,
            theme_text_color="Custom",
            text_color=ThemeConfig.GOLD_ACCENT,
            size_hint_y=None,
            height="18dp"
        )
        self.answer_label = MDLabel(
            text="",
            font_size="14sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_PRIMARY,
            size_hint_y=None
        )
        self.answer_label.bind(texture_size=self._update_text_size)

        box.add_widget(ans_header)
        box.add_widget(self.answer_label)
        self.answer_card.add_widget(box)
        scroll.add_widget(self.answer_card)

        layout.add_widget(scroll)
        self.add_widget(layout)

    def _update_bg(self, instance, value):
        self.bg_rect.pos = instance.pos
        self.bg_rect.size = instance.size

    def _update_text_size(self, instance, value):
        instance.height = value[1]

    def _handle_ask_click(self, *args):
        query = self.query_field.text.strip()
        if query and self.on_ask_submit:
            self.set_thinking_state()
            self.on_ask_submit(query)
