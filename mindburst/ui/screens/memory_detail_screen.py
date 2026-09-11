"""
Memory Detail Screen — View, Edit, Complete, and Delete Memory
Polished golden-white personal memory viewer and editor with zero technical noise.
"""
from typing import Optional, Callable, List
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

RETENTION_MODES = ["Temporary", "Keep Until Delete", "Permanent"]
RETENTION_ICONS = {
    "Temporary": "⏳ Temporary",
    "Keep Until Delete": "📌 Keep Until Delete",
    "Permanent": "♾️ Permanent"
}


class MemoryDetailScreen(MDScreen):
    def __init__(
        self,
        memory: Optional[Memory] = None,
        on_complete_cb: Optional[Callable[[Memory], None]] = None,
        on_save_edit_cb: Optional[Callable[[Memory], None]] = None,
        on_delete_cb: Optional[Callable[[Memory], None]] = None,
        on_back_cb: Optional[Callable[[], None]] = None,
        **kwargs
    ):
        super().__init__(**kwargs)
        self.memory = memory
        self.on_complete_cb = on_complete_cb
        self.on_save_edit_cb = on_save_edit_cb
        self.on_delete_cb = on_delete_cb
        self.on_back_cb = on_back_cb

        self.is_editing = False
        self.is_confirming_delete = False
        
        self.edit_category_idx = 0
        self.edit_retention_idx = 0

        self._build_ui()
        Window.bind(on_keyboard=self._on_keyboard_down)

    def set_memory(self, memory: Memory):
        """Populates detail screen widgets with selected memory."""
        self.memory = memory
        self.is_editing = False
        self.is_confirming_delete = False
        self._update_view_mode()

    def _build_ui(self):
        self.clear_widgets()

        layout = MDBoxLayout(
            orientation="vertical",
            padding=["20dp", "20dp", "20dp", "16dp"],
            spacing="12dp"
        )
        
        with layout.canvas.before:
            Color(*ThemeConfig.BACKGROUND_COLOR)
            self.bg_rect = Rectangle(pos=layout.pos, size=layout.size)
        layout.bind(pos=self._update_bg, size=self._update_bg)

        # Header Bar with Back Button
        header_bar = MDBoxLayout(orientation="horizontal", size_hint_y=None, height="36dp")
        back_btn = MDButton(style="text", size_hint=(None, 1.0), width="80dp")
        back_btn.add_widget(
            MDButtonText(text="← Back", theme_text_color="Custom", text_color=ThemeConfig.GOLD_ACCENT, bold=True)
        )
        back_btn.bind(on_release=self._handle_back)
        header_bar.add_widget(back_btn)

        self.screen_title_lbl = MDLabel(
            text="Memory Detail",
            font_size="16sp",
            bold=True,
            halign="right",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_SECONDARY
        )
        header_bar.add_widget(self.screen_title_lbl)
        layout.add_widget(header_bar)

        # Scrollable Body Container
        scroll = MDScrollView(size_hint=(1.0, 1.0))
        self.content_box = MDBoxLayout(
            orientation="vertical",
            spacing="12dp",
            size_hint_y=None
        )
        self.content_box.bind(minimum_height=self.content_box.setter("height"))
        scroll.add_widget(self.content_box)
        layout.add_widget(scroll)

        # Bottom Actions Container Bar
        self.actions_box = MDBoxLayout(
            orientation="horizontal",
            spacing="8dp",
            size_hint_y=None,
            height="46dp"
        )
        layout.add_widget(self.actions_box)

        self.add_widget(layout)

    def _update_view_mode(self):
        """Renders non-editing viewing mode for memory."""
        self.content_box.clear_widgets()
        self.actions_box.clear_widgets()

        if not self.memory:
            return

        mem = self.memory

        # Category & Retention Badges
        badge_row = MDBoxLayout(orientation="horizontal", spacing="8dp", size_hint_y=None, height="24dp")
        cat_badge = MDLabel(
            text=mem.category.upper(),
            font_size="12sp",
            bold=True,
            theme_text_color="Custom",
            text_color=ThemeConfig.GOLD_ACCENT
        )
        ret_badge = MDLabel(
            text=RETENTION_ICONS.get(mem.retention, mem.retention),
            font_size="11sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_SECONDARY,
            halign="right"
        )
        badge_row.add_widget(cat_badge)
        badge_row.add_widget(ret_badge)
        self.content_box.add_widget(badge_row)

        # Title Label
        title_prefix = "✔ " if mem.completed else ""
        title_lbl = MDLabel(
            text=f"{title_prefix}{mem.title}",
            font_size="20sp",
            bold=True,
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_PRIMARY if not mem.completed else ThemeConfig.TEXT_SECONDARY,
            size_hint_y=None
        )
        title_lbl.bind(texture_size=lambda instance, value: setattr(instance, 'height', value[1] + 8))
        self.content_box.add_widget(title_lbl)

        # Date & Time Subtitle
        human_date = DateNormalizer.format_human_date(mem.date)
        date_text = f"📅 Scheduled: {human_date}" if human_date != "No date" else "📅 Scheduled: No date"
        if mem.time:
            date_text += f" ({mem.time})"
            
        date_lbl = MDLabel(
            text=date_text,
            font_size="12sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_SECONDARY,
            size_hint_y=None,
            height="20dp"
        )
        self.content_box.add_widget(date_lbl)

        # Original Thought Card
        quote_card = MDCard(
            size_hint=(1.0, None),
            padding="14dp",
            md_bg_color=ThemeConfig.CARD_BACKGROUND,
            radius=[12, 12, 12, 12]
        )
        q_box = MDBoxLayout(orientation="vertical", spacing="4dp", size_hint_y=None)
        q_box.bind(minimum_height=q_box.setter("height"))

        q_header = MDLabel(
            text="YOUR THOUGHT",
            font_size="11sp",
            bold=True,
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_SECONDARY,
            size_hint_y=None,
            height="18dp"
        )
        q_text = MDLabel(
            text=f'"{mem.original_text or mem.details}"',
            font_size="13sp",
            italic=True,
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_PRIMARY,
            size_hint_y=None
        )
        q_text.bind(texture_size=lambda instance, value: setattr(instance, 'height', value[1] + 4))

        q_box.add_widget(q_header)
        q_box.add_widget(q_text)
        quote_card.add_widget(q_box)
        quote_card.bind(minimum_height=quote_card.setter("height"))
        self.content_box.add_widget(quote_card)

        # Entity Cards (Render ONLY when non-empty)
        if mem.people:
            self.content_box.add_widget(self._create_entity_row("👤 People", ", ".join(mem.people)))
        if mem.places:
            self.content_box.add_widget(self._create_entity_row("📍 Places", ", ".join(mem.places)))
        if mem.items:
            self.content_box.add_widget(self._create_entity_row("🎒 Items", ", ".join(mem.items)))
        if mem.projects:
            self.content_box.add_widget(self._create_entity_row("📁 Projects", ", ".join(mem.projects)))

        # Delete Confirmation view check
        if self.is_confirming_delete:
            self._render_delete_confirmation_box()
            return

        # Render Bottom Action Bar Buttons: [ Complete/Reopen ] [ Edit ] [ Delete ]
        # 1. Complete / Reopen Button
        self.complete_btn = MDButton(style="elevated", size_hint=(0.4, 1.0))
        self.complete_btn.md_bg_color = ThemeConfig.GOLD_ACCENT
        comp_text = "↩ Reopen" if mem.completed else "✓ Complete"
        self.complete_btn_lbl = MDButtonText(
            text=comp_text,
            bold=True,
            theme_text_color="Custom",
            text_color=(1, 1, 1, 1),
            font_size="12sp"
        )
        self.complete_btn.add_widget(self.complete_btn_lbl)
        self.complete_btn.bind(on_release=self._handle_complete_toggle)
        self.actions_box.add_widget(self.complete_btn)

        # 2. Edit Button
        edit_btn = MDButton(style="outlined", size_hint=(0.3, 1.0))
        edit_btn.add_widget(
            MDButtonText(text="✏️ Edit", theme_text_color="Custom", text_color=ThemeConfig.TEXT_PRIMARY, font_size="12sp")
        )
        edit_btn.bind(on_release=self._enable_edit_mode)
        self.actions_box.add_widget(edit_btn)

        # 3. Delete Button
        delete_btn = MDButton(style="outlined", size_hint=(0.3, 1.0))
        delete_btn.add_widget(
            MDButtonText(text="🗑️ Delete", theme_text_color="Custom", text_color=(0.9, 0.2, 0.2, 1), font_size="12sp")
        )
        delete_btn.bind(on_release=self._show_delete_confirmation)
        self.actions_box.add_widget(delete_btn)

    def _create_entity_row(self, label: str, value: str) -> MDCard:
        card = MDCard(
            size_hint=(1.0, None),
            height="44dp",
            padding=["12dp", "6dp", "12dp", "6dp"],
            md_bg_color=ThemeConfig.CARD_BACKGROUND,
            radius=[8, 8, 8, 8]
        )
        box = MDBoxLayout(orientation="horizontal", spacing="8dp")
        lbl = MDLabel(
            text=label,
            font_size="11sp",
            bold=True,
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_SECONDARY,
            size_hint=(0.35, 1.0)
        )
        val = MDLabel(
            text=value,
            font_size="12sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_PRIMARY,
            size_hint=(0.65, 1.0)
        )
        box.add_widget(lbl)
        box.add_widget(val)
        card.add_widget(box)
        return card

    def _enable_edit_mode(self, *args):
        """Switches to inline edit mode for title, details, category, date, and retention."""
        self.is_editing = True
        self.content_box.clear_widgets()
        self.actions_box.clear_widgets()

        mem = self.memory

        # Category Selector Index
        if mem.category in ALLOWED_CATEGORIES:
            self.edit_category_idx = ALLOWED_CATEGORIES.index(mem.category)
        else:
            self.edit_category_idx = 0

        # Retention Selector Index
        if mem.retention in RETENTION_MODES:
            self.edit_retention_idx = RETENTION_MODES.index(mem.retention)
        else:
            self.edit_retention_idx = 0

        # Title Edit Field
        title_card = MDCard(size_hint=(1.0, None), height="64dp", padding="8dp", md_bg_color=ThemeConfig.CARD_BACKGROUND, radius=[8, 8, 8, 8])
        self.edit_title_field = MDTextField(mode="outlined", text=mem.title, size_hint=(1.0, 1.0))
        self.edit_title_field.add_widget(MDTextFieldHintText(text="Memory Title"))
        title_card.add_widget(self.edit_title_field)
        self.content_box.add_widget(title_card)

        # Details Edit Field
        details_card = MDCard(size_hint=(1.0, None), height="90dp", padding="8dp", md_bg_color=ThemeConfig.CARD_BACKGROUND, radius=[8, 8, 8, 8])
        self.edit_details_field = MDTextField(mode="outlined", multiline=True, text=mem.details or mem.original_text or "", size_hint=(1.0, 1.0))
        self.edit_details_field.add_widget(MDTextFieldHintText(text="Details / Thought"))
        details_card.add_widget(self.edit_details_field)
        self.content_box.add_widget(details_card)

        # Date Edit Field
        date_card = MDCard(size_hint=(1.0, None), height="64dp", padding="8dp", md_bg_color=ThemeConfig.CARD_BACKGROUND, radius=[8, 8, 8, 8])
        self.edit_date_field = MDTextField(mode="outlined", text=mem.date or "", size_hint=(1.0, 1.0))
        self.edit_date_field.add_widget(MDTextFieldHintText(text="Date (YYYY-MM-DD or Tomorrow)"))
        date_card.add_widget(self.edit_date_field)
        self.content_box.add_widget(date_card)

        # Selectors Row: [ Category ] [ Retention ]
        selector_row = MDBoxLayout(orientation="horizontal", spacing="8dp", size_hint_y=None, height="44dp")
        
        self.edit_category_btn = MDButton(style="outlined", size_hint=(0.5, 1.0))
        self.edit_category_lbl = MDButtonText(text=f"🏷️ {ALLOWED_CATEGORIES[self.edit_category_idx]}", font_size="11sp", theme_text_color="Custom", text_color=ThemeConfig.TEXT_PRIMARY)
        self.edit_category_btn.add_widget(self.edit_category_lbl)
        self.edit_category_btn.bind(on_release=self._cycle_edit_category)
        selector_row.add_widget(self.edit_category_btn)

        self.edit_retention_btn = MDButton(style="outlined", size_hint=(0.5, 1.0))
        self.edit_retention_lbl = MDButtonText(text=f"{RETENTION_ICONS[RETENTION_MODES[self.edit_retention_idx]]}", font_size="11sp", theme_text_color="Custom", text_color=ThemeConfig.TEXT_PRIMARY)
        self.edit_retention_btn.add_widget(self.edit_retention_lbl)
        self.edit_retention_btn.bind(on_release=self._cycle_edit_retention)
        selector_row.add_widget(self.edit_retention_btn)

        self.content_box.add_widget(selector_row)

        # Action Buttons: [ Save Edits ] [ Cancel ]
        save_btn = MDButton(style="elevated", size_hint=(0.5, 1.0))
        save_btn.md_bg_color = ThemeConfig.GOLD_ACCENT
        save_btn.add_widget(MDButtonText(text="Save Edits", bold=True, theme_text_color="Custom", text_color=(1, 1, 1, 1)))
        save_btn.bind(on_release=self._handle_save_edits)
        self.actions_box.add_widget(save_btn)

        cancel_btn = MDButton(style="outlined", size_hint=(0.5, 1.0))
        cancel_btn.add_widget(MDButtonText(text="Cancel", theme_text_color="Custom", text_color=ThemeConfig.TEXT_PRIMARY))
        cancel_btn.bind(on_release=self._cancel_edit_mode)
        self.actions_box.add_widget(cancel_btn)

    def _cycle_edit_category(self, *args):
        self.edit_category_idx = (self.edit_category_idx + 1) % len(ALLOWED_CATEGORIES)
        self.edit_category_lbl.text = f"🏷️ {ALLOWED_CATEGORIES[self.edit_category_idx]}"

    def _cycle_edit_retention(self, *args):
        self.edit_retention_idx = (self.edit_retention_idx + 1) % len(RETENTION_MODES)
        mode = RETENTION_MODES[self.edit_retention_idx]
        self.edit_retention_lbl.text = f"{RETENTION_ICONS[mode]}"

    def _handle_save_edits(self, *args):
        """Validates and persists edited memory fields."""
        if not self.memory:
            return

        new_title = self.edit_title_field.text.strip()
        new_details = self.edit_details_field.text.strip()
        raw_date = self.edit_date_field.text.strip()
        new_category = ALLOWED_CATEGORIES[self.edit_category_idx]
        new_retention = RETENTION_MODES[self.edit_retention_idx]

        if not new_title:
            new_title = self.memory.title

        # Resolve date
        resolved_date = DateNormalizer.resolve_date(raw_date) if raw_date else None

        self.memory.title = new_title
        self.memory.details = new_details
        self.memory.date = resolved_date
        self.memory.category = new_category
        self.memory.retention = new_retention

        if self.on_save_edit_cb:
            self.on_save_edit_cb(self.memory)

        self.is_editing = False
        self._update_view_mode()

    def _cancel_edit_mode(self, *args):
        self.is_editing = False
        self._update_view_mode()

    def _show_delete_confirmation(self, *args):
        self.is_confirming_delete = True
        self._update_view_mode()

    def _render_delete_confirmation_box(self):
        self.actions_box.clear_widgets()

        confirm_card = MDCard(
            size_hint=(1.0, None),
            padding="14dp",
            md_bg_color=ThemeConfig.CARD_BACKGROUND,
            radius=[12, 12, 12, 12]
        )
        c_box = MDBoxLayout(orientation="vertical", spacing="8dp", size_hint_y=None)
        c_box.bind(minimum_height=c_box.setter("height"))

        c_title = MDLabel(
            text="Delete this memory?",
            font_size="14sp",
            bold=True,
            theme_text_color="Custom",
            text_color=(0.9, 0.2, 0.2, 1),
            size_hint_y=None,
            height="20dp"
        )
        c_msg = MDLabel(
            text="This memory will be removed from your active memories.",
            font_size="12sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_SECONDARY,
            size_hint_y=None,
            height="20dp"
        )
        c_box.add_widget(c_title)
        c_box.add_widget(c_msg)
        confirm_card.add_widget(c_box)
        confirm_card.bind(minimum_height=confirm_card.setter("height"))
        self.content_box.add_widget(confirm_card)

        # Action Buttons: [ Yes, Delete ] [ Cancel ]
        yes_btn = MDButton(style="elevated", size_hint=(0.5, 1.0))
        yes_btn.md_bg_color = (0.9, 0.2, 0.2, 1)
        yes_btn.add_widget(MDButtonText(text="Yes, Delete", bold=True, theme_text_color="Custom", text_color=(1, 1, 1, 1)))
        yes_btn.bind(on_release=self._confirm_delete)
        self.actions_box.add_widget(yes_btn)

        cancel_btn = MDButton(style="outlined", size_hint=(0.5, 1.0))
        cancel_btn.add_widget(MDButtonText(text="Cancel", theme_text_color="Custom", text_color=ThemeConfig.TEXT_PRIMARY))
        cancel_btn.bind(on_release=self._cancel_delete)
        self.actions_box.add_widget(cancel_btn)

    def _confirm_delete(self, *args):
        if self.memory and self.on_delete_cb:
            self.on_delete_cb(self.memory)

    def _cancel_delete(self, *args):
        self.is_confirming_delete = False
        self._update_view_mode()

    def _handle_complete_toggle(self, *args):
        if self.memory and self.on_complete_cb:
            self.on_complete_cb(self.memory)
            self._update_view_mode()

    def _handle_back(self, *args):
        if self.on_back_cb:
            self.on_back_cb()

    def _on_keyboard_down(self, window, key, *args):
        """Android hardware back button listener (key 27)."""
        if key == 27 and self.parent:
            self._handle_back()
            return True
        return False

    def _update_bg(self, instance, value):
        self.bg_rect.pos = instance.pos
        self.bg_rect.size = instance.size
