"""
Understanding Screen — AI Extraction Confirmation & Edit Workflow
Confirmation gate between AI extraction and permanent memory storage.
Visual aesthetic: Golden-white + thin futuristic/JARVIS visual language.
"""
import copy
from typing import List, Callable, Optional
from kivymd.uix.screen import MDScreen
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.label import MDLabel
from kivymd.uix.button import MDButton, MDButtonText
from kivymd.uix.textfield import MDTextField, MDTextFieldHintText
from kivymd.uix.card import MDCard
from kivymd.uix.scrollview import MDScrollView
from kivy.graphics import Color, Rectangle
from kivy.core.window import Window

from mindburst.ui.theme.theme_config import ThemeConfig
from mindburst.database.models import Memory
from mindburst.utils.date_normalizer import DateNormalizer

ALLOWED_CATEGORIES = [
    "Carry", "Tasks", "Shopping", "Ideas", "College",
    "Projects", "Personal", "Things to Use", "Important", "Notes"
]

ALLOWED_RETENTIONS = ["Temporary", "Keep Until Delete", "Permanent"]

TYPE_ICONS = {
    "Carry": "🎒",
    "Task": "✓",
    "Shopping": "🛒",
    "Idea": "💡",
    "Memory": "🧠",
    "Note": "📝"
}

class MemoryCardItem(MDCard):
    """Editable memory card widget for Understanding Screen."""
    def __init__(self, memory: Memory, **kwargs):
        super().__init__(**kwargs)
        # Deep clone memory model to isolate edits
        self.memory = copy.deepcopy(memory)
        self.size_hint = (1.0, None)
        self.padding = "16dp"
        self.spacing = "10dp"
        self.orientation = "vertical"
        self.md_bg_color = ThemeConfig.CARD_BACKGROUND
        self.radius = [14, 14, 14, 14]
        
        self.current_retention_idx = (
            ALLOWED_RETENTIONS.index(self.memory.retention)
            if self.memory.retention in ALLOWED_RETENTIONS
            else 0
        )
        
        self._build_card()

    def _build_card(self):
        self.clear_widgets()
        
        # Header Row: Type Badge + Natural Category
        header_row = MDBoxLayout(orientation="horizontal", spacing="8dp", size_hint_y=None, height="28dp")
        type_icon = TYPE_ICONS.get(self.memory.type, "📝")
        
        type_lbl = MDLabel(
            text=f"{type_icon} {self.memory.type}",
            font_size="13sp",
            bold=True,
            theme_text_color="Custom",
            text_color=ThemeConfig.GOLD_ACCENT,
            size_hint=(None, 1.0),
            width="90dp"
        )
        
        cat_badge = MDLabel(
            text=f"[{self.memory.category}]",
            font_size="12sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_SECONDARY,
            size_hint=(1.0, 1.0)
        )
        header_row.add_widget(type_lbl)
        header_row.add_widget(cat_badge)
        self.add_widget(header_row)

        # Row 1: Editable Title Field
        self.title_field = MDTextField(
            text=self.memory.title,
            mode="outlined",
            size_hint=(1.0, None),
            height="48dp"
        )
        self.title_field.add_widget(MDTextFieldHintText(text="Memory Title"))
        self.add_widget(self.title_field)

        # Row 2: Editable Category & Date Fields
        meta_row = MDBoxLayout(orientation="horizontal", spacing="8dp", size_hint_y=None, height="48dp")
        
        self.category_field = MDTextField(
            text=self.memory.category,
            mode="outlined",
            size_hint=(0.5, 1.0)
        )
        self.category_field.add_widget(MDTextFieldHintText(text="Category"))
        
        self.date_field = MDTextField(
            text=self.memory.date or "",
            mode="outlined",
            size_hint=(0.5, 1.0)
        )
        self.date_field.add_widget(MDTextFieldHintText(text="Date (YYYY-MM-DD)"))
        
        meta_row.add_widget(self.category_field)
        meta_row.add_widget(self.date_field)
        self.add_widget(meta_row)

        # Row 3: Human-Readable Date & Retention Row
        info_row = MDBoxLayout(orientation="horizontal", spacing="8dp", size_hint_y=None, height="32dp")
        
        human_date = DateNormalizer.format_human_date(self.memory.date)
        self.date_display_lbl = MDLabel(
            text=f"🗓️ {human_date}",
            font_size="12sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_SECONDARY,
            size_hint=(0.5, 1.0)
        )
        
        # Retention Cycle Button
        self.retention_btn = MDButton(
            style="outlined",
            size_hint=(0.5, 1.0)
        )
        self.retention_btn_text = MDButtonText(
            text=f"⏳ {self.memory.retention}",
            font_size="11sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_PRIMARY
        )
        self.retention_btn.add_widget(self.retention_btn_text)
        self.retention_btn.bind(on_release=self._cycle_retention)
        
        info_row.add_widget(self.date_display_lbl)
        info_row.add_widget(self.retention_btn)
        self.add_widget(info_row)

        # Row 4: Dynamic Extracted Entities Section (ONLY RENDER NON-EMPTY ENTITIES)
        entities_text_parts = []
        if self.memory.items:
            entities_text_parts.append(f"🎒 Items: {', '.join(self.memory.items)}")
        if self.memory.people:
            entities_text_parts.append(f"👤 Person: {', '.join(self.memory.people)}")
        if self.memory.places:
            entities_text_parts.append(f"📍 Place: {', '.join(self.memory.places)}")
        if self.memory.projects:
            entities_text_parts.append(f"📁 Project: {', '.join(self.memory.projects)}")

        if entities_text_parts:
            entity_box = MDBoxLayout(
                orientation="vertical",
                spacing="2dp",
                size_hint_y=None,
                height=f"{len(entities_text_parts) * 18}dp"
            )
            for part in entities_text_parts:
                lbl = MDLabel(
                    text=part,
                    font_size="11sp",
                    theme_text_color="Custom",
                    text_color=ThemeConfig.TEXT_SECONDARY,
                    size_hint_y=None,
                    height="18dp"
                )
                entity_box.add_widget(lbl)
            self.add_widget(entity_box)

        # Calculate height dynamically based on widgets added
        base_height = 200
        if entities_text_parts:
            base_height += len(entities_text_parts) * 18
        self.height = f"{base_height}dp"

    def _cycle_retention(self, *args):
        """Cycles retention mode between Temporary, Keep Until Delete, and Permanent."""
        self.current_retention_idx = (self.current_retention_idx + 1) % len(ALLOWED_RETENTIONS)
        new_retention = ALLOWED_RETENTIONS[self.current_retention_idx]
        self.memory.retention = new_retention
        
        icon = "⏳" if new_retention == "Temporary" else ("📌" if new_retention == "Keep Until Delete" else "♾️")
        self.retention_btn_text.text = f"{icon} {new_retention}"

    def get_updated_memory(self) -> Memory:
        """Applies user edits to the cloned Memory instance and returns it."""
        # 1. Update Title
        new_title = self.title_field.text.strip()
        if new_title:
            self.memory.title = new_title

        # 2. Update Category
        new_cat = self.category_field.text.strip()
        if new_cat:
            self.memory.category = new_cat

        # 3. Update Date (normalize ISO format via DateNormalizer)
        raw_date = self.date_field.text.strip()
        if raw_date:
            norm_date = DateNormalizer.resolve_date(raw_date)
            self.memory.date = norm_date
        else:
            self.memory.date = None

        return self.memory


class UnderstandingScreen(MDScreen):
    def __init__(
        self,
        original_text: str = "",
        extracted_memories: Optional[List[Memory]] = None,
        on_save_cb: Optional[Callable[[List[Memory]], None]] = None,
        on_cancel_cb: Optional[Callable[[], None]] = None,
        **kwargs
    ):
        super().__init__(**kwargs)
        self.original_text = original_text
        self.extracted_memories = [copy.deepcopy(m) for m in (extracted_memories or [])]
        self.on_save_cb = on_save_cb
        self.on_cancel_cb = on_cancel_cb
        self.card_widgets: List[MemoryCardItem] = []
        self._build_ui()

    def on_enter(self):
        super().on_enter()
        Window.bind(on_keyboard=self._handle_hardware_back)

    def on_leave(self):
        super().on_leave()
        Window.unbind(on_keyboard=self._handle_hardware_back)

    def _handle_hardware_back(self, window, key, *args):
        """Android hardware back button safety handler (key 27 = Escape/Back)."""
        if key == 27:
            self._handle_cancel()
            return True
        return False

    def set_data(self, original_text: str, extracted_memories: List[Memory]):
        self.original_text = original_text
        self.extracted_memories = [copy.deepcopy(m) for m in extracted_memories]
        self.original_label.text = f'"{original_text}"'
        self.cards_layout.clear_widgets()
        self.card_widgets = []

        for mem in self.extracted_memories:
            card = MemoryCardItem(mem)
            self.card_widgets.append(card)
            self.cards_layout.add_widget(card)

    def _build_ui(self):
        layout = MDBoxLayout(
            orientation="vertical",
            padding=["20dp", "24dp", "20dp", "16dp"],
            spacing="12dp"
        )
        
        with layout.canvas.before:
            Color(*ThemeConfig.BACKGROUND_COLOR)
            self.bg_rect = Rectangle(pos=layout.pos, size=layout.size)
        layout.bind(pos=self._update_bg, size=self._update_bg)

        # Header Title: "Here's what I understood."
        header_box = MDBoxLayout(orientation="vertical", spacing="2dp", size_hint_y=None, height="48dp")
        header = MDLabel(
            text="Here's what I understood.",
            font_size="20sp",
            bold=True,
            theme_text_color="Custom",
            text_color=ThemeConfig.GOLD_ACCENT,
            size_hint_y=None,
            height="26dp"
        )
        sub_header = MDLabel(
            text="Is this right? Review & edit before saving",
            font_size="12sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_SECONDARY,
            size_hint_y=None,
            height="18dp"
        )
        header_box.add_widget(header)
        header_box.add_widget(sub_header)
        layout.add_widget(header_box)

        # Original Thought Quote Card ("Your thought")
        quote_card = MDCard(
            size_hint=(1.0, None),
            height="80dp",
            padding="12dp",
            orientation="vertical",
            md_bg_color=ThemeConfig.GOLD_ACCENT_LIGHT,
            radius=[12, 12, 12, 12]
        )
        quote_tag = MDLabel(
            text="YOUR THOUGHT",
            font_size="10sp",
            bold=True,
            theme_text_color="Custom",
            text_color=ThemeConfig.GOLD_ACCENT,
            size_hint_y=None,
            height="14dp"
        )
        self.original_label = MDLabel(
            text=f'"{self.original_text}"',
            font_size="13sp",
            italic=True,
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_PRIMARY
        )
        quote_card.add_widget(quote_tag)
        quote_card.add_widget(self.original_label)
        layout.add_widget(quote_card)

        # Scrollable Extracted Memories List
        scroll = MDScrollView(size_hint=(1.0, 1.0))
        self.cards_layout = MDBoxLayout(
            orientation="vertical",
            spacing="12dp",
            size_hint_y=None
        )
        self.cards_layout.bind(minimum_height=self.cards_layout.setter("height"))

        for mem in self.extracted_memories:
            card = MemoryCardItem(mem)
            self.card_widgets.append(card)
            self.cards_layout.add_widget(card)

        scroll.add_widget(self.cards_layout)
        layout.add_widget(scroll)

        # Bottom Actions [ Cancel ] [ Save ]
        actions = MDBoxLayout(
            orientation="horizontal",
            spacing="16dp",
            size_hint_y=None,
            height="48dp"
        )
        
        cancel_btn = MDButton(
            style="outlined",
            size_hint=(0.5, 1.0)
        )
        cancel_btn.add_widget(
            MDButtonText(
                text="Cancel",
                theme_text_color="Custom",
                text_color=ThemeConfig.TEXT_PRIMARY
            )
        )
        cancel_btn.bind(on_release=self._handle_cancel)
        actions.add_widget(cancel_btn)

        save_btn = MDButton(
            style="elevated",
            size_hint=(0.5, 1.0)
        )
        save_btn.md_bg_color = ThemeConfig.GOLD_ACCENT
        save_btn.add_widget(
            MDButtonText(
                text="✓ Save",
                bold=True,
                theme_text_color="Custom",
                text_color=(1, 1, 1, 1)
            )
        )
        save_btn.bind(on_release=self._handle_save)
        actions.add_widget(save_btn)

        layout.add_widget(actions)
        self.add_widget(layout)

    def _update_bg(self, instance, value):
        self.bg_rect.pos = instance.pos
        self.bg_rect.size = instance.size

    def _handle_cancel(self, *args):
        if self.on_cancel_cb:
            self.on_cancel_cb()

    def _handle_save(self, *args):
        # Collect updated memory models from cards
        updated_memories = [card.get_updated_memory() for card in self.card_widgets]
        if self.on_save_cb:
            self.on_save_cb(updated_memories)
