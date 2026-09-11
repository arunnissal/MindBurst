"""
All / Memory Browser Screen
Unified memory timeline feed with multi-field search, date/category/retention filters, and empty state.
Aesthetic: Golden-white light palette + thin futuristic/JARVIS visual language.
"""
from typing import List, Optional, Callable, Dict
from kivymd.uix.screen import MDScreen
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.label import MDLabel
from kivymd.uix.button import MDButton, MDButtonText
from kivymd.uix.textfield import MDTextField, MDTextFieldHintText
from kivymd.uix.card import MDCard
from kivymd.uix.scrollview import MDScrollView
from kivy.graphics import Color, Rectangle

from mindburst.ui.theme.theme_config import ThemeConfig
from mindburst.database.models import Memory
from mindburst.utils.date_normalizer import DateNormalizer

ALLOWED_CATEGORIES = [
    "All", "Carry", "Tasks", "Shopping", "Ideas", "College",
    "Projects", "Personal", "Things to Use", "Important", "Notes"
]

DATE_FILTER_OPTIONS = [
    "All", "Today", "Yesterday", "This week", "This month", "Custom"
]

RETENTION_FILTER_OPTIONS = [
    "All", "Temporary", "Keep Until Delete", "Permanent"
]

TYPE_ICONS = {
    "Carry": "🎒",
    "Task": "✓",
    "Shopping": "🛒",
    "Idea": "💡",
    "Memory": "🧠",
    "Note": "📝"
}

class AllScreen(MDScreen):
    def __init__(
        self,
        on_select_memory_cb: Optional[Callable[[Memory], None]] = None,
        on_filter_change_cb: Optional[Callable[[Dict[str, Optional[str]]], None]] = None,
        on_burst_navigate_cb: Optional[Callable[[], None]] = None,
        **kwargs
    ):
        super().__init__(**kwargs)
        self.on_select_memory_cb = on_select_memory_cb
        self.on_filter_change_cb = on_filter_change_cb
        self.on_burst_navigate_cb = on_burst_navigate_cb
        
        self.current_query = ""
        self.current_date_filter_idx = 0
        self.current_category_filter_idx = 0
        self.current_retention_filter_idx = 0
        self.custom_start_date: Optional[str] = None
        self.custom_end_date: Optional[str] = None

        self.memories: List[Memory] = []
        self._build_ui()

    def set_memories(self, memories: List[Memory]):
        self.memories = memories
        self.memory_list.clear_widgets()

        if not memories:
            # Empty State Card
            empty_box = MDBoxLayout(
                orientation="vertical",
                spacing="12dp",
                padding="24dp",
                size_hint=(1.0, None),
                height="220dp"
            )
            empty_lbl = MDLabel(
                text="Nothing here yet.\nYour thoughts will appear here after your first MindBurst.",
                halign="center",
                font_size="14sp",
                theme_text_color="Custom",
                text_color=ThemeConfig.TEXT_SECONDARY,
                size_hint_y=None,
                height="48dp"
            )
            
            burst_btn = MDButton(
                style="elevated",
                size_hint=(None, None),
                size=("180dp", "44dp"),
                pos_hint={"center_x": 0.5}
            )
            burst_btn.md_bg_color = ThemeConfig.GOLD_ACCENT
            burst_btn.add_widget(
                MDButtonText(
                    text="💥 Burst something",
                    bold=True,
                    theme_text_color="Custom",
                    text_color=(1, 1, 1, 1)
                )
            )
            burst_btn.bind(on_release=self._handle_burst_navigate)

            empty_box.add_widget(empty_lbl)
            empty_box.add_widget(burst_btn)
            self.memory_list.add_widget(empty_box)
            return

        # Render Chronological Feed
        for mem in memories:
            row = self._create_memory_row(mem)
            self.memory_list.add_widget(row)

    def _build_ui(self):
        layout = MDBoxLayout(
            orientation="vertical",
            padding=["16dp", "20dp", "16dp", "8dp"],
            spacing="10dp"
        )

        with layout.canvas.before:
            Color(*ThemeConfig.BACKGROUND_COLOR)
            self.bg_rect = Rectangle(pos=layout.pos, size=layout.size)
        layout.bind(pos=self._update_bg, size=self._update_bg)

        # Header Title: All Memories + Recently Deleted Navigation Button
        header_box = MDBoxLayout(orientation="horizontal", size_hint_y=None, height="32dp")
        header = MDLabel(
            text="All Memories",
            font_size="22sp",
            bold=True,
            theme_text_color="Custom",
            text_color=ThemeConfig.GOLD_ACCENT,
            size_hint=(0.7, 1.0)
        )
        header_box.add_widget(header)

        deleted_nav_btn = MDButton(style="text", size_hint=(0.3, 1.0))
        deleted_nav_lbl = MDButtonText(
            text="🗑️ Deleted",
            font_size="11sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_SECONDARY
        )
        deleted_nav_btn.add_widget(deleted_nav_lbl)
        deleted_nav_btn.bind(on_release=self._handle_deleted_navigate)
        header_box.add_widget(deleted_nav_btn)

        layout.add_widget(header_box)

        # Search Field Card
        search_card = MDCard(
            size_hint=(1.0, None),
            height="52dp",
            padding="6dp",
            md_bg_color=ThemeConfig.CARD_BACKGROUND,
            radius=[12, 12, 12, 12]
        )
        self.search_field = MDTextField(
            mode="outlined",
            size_hint=(1.0, 1.0)
        )
        self.search_field.add_widget(
            MDTextFieldHintText(text="Search memories...")
        )
        self.search_field.bind(text=self._on_search_text_changed)
        search_card.add_widget(self.search_field)
        layout.add_widget(search_card)

        # Filter Controls Row: [ Date ] [ Category ] [ Retention ]
        filter_row = MDBoxLayout(
            orientation="horizontal",
            spacing="8dp",
            size_hint_y=None,
            height="36dp"
        )
        
        # Date Filter Button
        self.date_filter_btn = MDButton(style="outlined", size_hint=(0.33, 1.0))
        self.date_filter_lbl = MDButtonText(
            text=f"📅 {DATE_FILTER_OPTIONS[0]}",
            font_size="11sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_PRIMARY
        )
        self.date_filter_btn.add_widget(self.date_filter_lbl)
        self.date_filter_btn.bind(on_release=self._cycle_date_filter)
        filter_row.add_widget(self.date_filter_btn)

        # Category Filter Button
        self.category_filter_btn = MDButton(style="outlined", size_hint=(0.33, 1.0))
        self.category_filter_lbl = MDButtonText(
            text=f"🏷️ {ALLOWED_CATEGORIES[0]}",
            font_size="11sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_PRIMARY
        )
        self.category_filter_btn.add_widget(self.category_filter_lbl)
        self.category_filter_btn.bind(on_release=self._cycle_category_filter)
        filter_row.add_widget(self.category_filter_btn)

        # Retention Filter Button
        self.retention_filter_btn = MDButton(style="outlined", size_hint=(0.34, 1.0))
        self.retention_filter_lbl = MDButtonText(
            text=f"⏳ {RETENTION_FILTER_OPTIONS[0]}",
            font_size="11sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_PRIMARY
        )
        self.retention_filter_btn.add_widget(self.retention_filter_lbl)
        self.retention_filter_btn.bind(on_release=self._cycle_retention_filter)
        filter_row.add_widget(self.retention_filter_btn)

        layout.add_widget(filter_row)

        # Clear Filters Bar (Hidden by default, shown when filters active)
        self.clear_bar = MDBoxLayout(
            orientation="horizontal",
            size_hint_y=None,
            height="28dp"
        )
        self.clear_btn = MDButton(style="text", size_hint=(None, 1.0), width="120dp")
        self.clear_btn_lbl = MDButtonText(
            text="Clear filters ✕",
            font_size="11sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.GOLD_ACCENT
        )
        self.clear_btn.add_widget(self.clear_btn_lbl)
        self.clear_btn.bind(on_release=self.reset_all_filters)
        self.clear_bar.add_widget(self.clear_btn)
        # Add to layout
        layout.add_widget(self.clear_bar)

        # Memory Feed List ScrollView
        scroll = MDScrollView(size_hint=(1.0, 1.0))
        self.memory_list = MDBoxLayout(
            orientation="vertical",
            spacing="8dp",
            size_hint_y=None
        )
        self.memory_list.bind(minimum_height=self.memory_list.setter("height"))

        scroll.add_widget(self.memory_list)
        layout.add_widget(scroll)

        self.add_widget(layout)

    def _create_memory_row(self, memory: Memory) -> MDCard:
        card = MDCard(
            size_hint=(1.0, None),
            height="64dp",
            padding=["12dp", "8dp", "12dp", "8dp"],
            md_bg_color=ThemeConfig.CARD_BACKGROUND,
            radius=[8, 8, 8, 8]
        )
        box = MDBoxLayout(orientation="vertical", spacing="2dp")
        
        icon = TYPE_ICONS.get(memory.type, "📝")
        completed_prefix = "✔ " if memory.completed else ""
        
        title_lbl = MDLabel(
            text=f"{completed_prefix}{icon} {memory.title}",
            font_size="14sp",
            bold=not memory.completed,
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_PRIMARY if not memory.completed else ThemeConfig.TEXT_SECONDARY
        )
        
        # Format human-friendly subtitle
        sub_parts = [memory.category]
        human_date = DateNormalizer.format_human_date(memory.date)
        if human_date != "No date":
            sub_parts.append(human_date)
            
        if memory.people:
            sub_parts.append(f"👤 {', '.join(memory.people)}")
        if memory.places:
            sub_parts.append(f"📍 {', '.join(memory.places)}")
        if memory.items:
            sub_parts.append(f"🎒 {', '.join(memory.items)}")
        if memory.projects:
            sub_parts.append(f"📁 {', '.join(memory.projects)}")

        sub_lbl = MDLabel(
            text=" · ".join(sub_parts),
            font_size="11sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_SECONDARY
        )
        
        box.add_widget(title_lbl)
        box.add_widget(sub_lbl)
        card.add_widget(box)

        # Bind click to select memory callback
        card.bind(on_release=lambda instance, m=memory: self._handle_select_memory(m))
        return card

    def _update_bg(self, instance, value):
        self.bg_rect.pos = instance.pos
        self.bg_rect.size = instance.size

    def _cycle_date_filter(self, *args):
        self.current_date_filter_idx = (self.current_date_filter_idx + 1) % len(DATE_FILTER_OPTIONS)
        val = DATE_FILTER_OPTIONS[self.current_date_filter_idx]
        self.date_filter_lbl.text = f"📅 {val}"
        self._notify_filter_changed()

    def _cycle_category_filter(self, *args):
        self.current_category_filter_idx = (self.current_category_filter_idx + 1) % len(ALLOWED_CATEGORIES)
        val = ALLOWED_CATEGORIES[self.current_category_filter_idx]
        self.category_filter_lbl.text = f"🏷️ {val}"
        self._notify_filter_changed()

    def _cycle_retention_filter(self, *args):
        self.current_retention_filter_idx = (self.current_retention_filter_idx + 1) % len(RETENTION_FILTER_OPTIONS)
        val = RETENTION_FILTER_OPTIONS[self.current_retention_filter_idx]
        self.retention_filter_lbl.text = f"⏳ {val}"
        self._notify_filter_changed()

    def set_custom_date_range(self, start_date: str, end_date: str):
        """Sets custom start and end date for custom filter option."""
        self.custom_start_date = start_date
        self.custom_end_date = end_date
        # Set date filter to Custom
        self.current_date_filter_idx = DATE_FILTER_OPTIONS.index("Custom")
        self.date_filter_lbl.text = "📅 Custom"
        self._notify_filter_changed()

    def reset_all_filters(self, *args):
        """Resets search query and all filter options to default ('All')."""
        self.current_query = ""
        self.search_field.text = ""
        self.current_date_filter_idx = 0
        self.current_category_filter_idx = 0
        self.current_retention_filter_idx = 0
        self.custom_start_date = None
        self.custom_end_date = None
        
        self.date_filter_lbl.text = f"📅 {DATE_FILTER_OPTIONS[0]}"
        self.category_filter_lbl.text = f"🏷️ {ALLOWED_CATEGORIES[0]}"
        self.retention_filter_lbl.text = f"⏳ {RETENTION_FILTER_OPTIONS[0]}"
        
        self._notify_filter_changed()

    def _on_search_text_changed(self, instance, value):
        self.current_query = value.strip()
        self._notify_filter_changed()

    def _notify_filter_changed(self):
        date_opt = DATE_FILTER_OPTIONS[self.current_date_filter_idx]
        start_date, end_date = DateNormalizer.get_date_range_for_filter(
            date_opt,
            custom_start=self.custom_start_date,
            custom_end=self.custom_end_date
        )

        filter_state = {
            "query": self.current_query if self.current_query else None,
            "category": ALLOWED_CATEGORIES[self.current_category_filter_idx],
            "retention": RETENTION_FILTER_OPTIONS[self.current_retention_filter_idx],
            "date_option": date_opt,
            "start_date": start_date,
            "end_date": end_date
        }

        if self.on_filter_change_cb:
            self.on_filter_change_cb(filter_state)

    def _handle_select_memory(self, memory: Memory):
        if self.on_select_memory_cb:
            self.on_select_memory_cb(memory)

    def _handle_burst_navigate(self, *args):
        if self.on_burst_navigate_cb:
            self.on_burst_navigate_cb()

    def _handle_deleted_navigate(self, *args):
        if self.on_deleted_navigate_cb:
            self.on_deleted_navigate_cb()

