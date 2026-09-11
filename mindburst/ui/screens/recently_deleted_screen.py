"""
Recently Deleted Screen — MindBurst
Browse, restore, and permanently delete soft-deleted memories.
Golden-white theme with zero technical noise.
"""
from typing import List, Optional, Callable
from kivymd.uix.screen import MDScreen
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.label import MDLabel
from kivymd.uix.button import MDButton, MDButtonText
from kivymd.uix.card import MDCard
from kivymd.uix.scrollview import MDScrollView
from kivy.graphics import Color, Rectangle
from kivy.core.window import Window

from mindburst.ui.theme.theme_config import ThemeConfig
from mindburst.database.models import Memory
from mindburst.utils.date_normalizer import DateNormalizer


class RecentlyDeletedScreen(MDScreen):
    def __init__(
        self,
        deleted_memories: Optional[List[Memory]] = None,
        on_restore_cb: Optional[Callable[[Memory], None]] = None,
        on_delete_forever_cb: Optional[Callable[[Memory], None]] = None,
        on_back_cb: Optional[Callable[[], None]] = None,
        **kwargs
    ):
        super().__init__(**kwargs)
        self.deleted_memories = deleted_memories or []
        self.on_restore_cb = on_restore_cb
        self.on_delete_forever_cb = on_delete_forever_cb
        self.on_back_cb = on_back_cb

        self.confirming_delete_id: Optional[int] = None

        self._build_ui()
        Window.bind(on_keyboard=self._on_keyboard_down)

    def set_deleted_memories(self, memories: List[Memory]):
        """Sets the list of deleted memories and updates the UI."""
        self.deleted_memories = memories
        self.confirming_delete_id = None
        self._render_feed()

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

        # Header Bar
        header_bar = MDBoxLayout(orientation="horizontal", size_hint_y=None, height="36dp")
        back_btn = MDButton(style="text", size_hint=(None, 1.0), width="80dp")
        back_btn.add_widget(
            MDButtonText(text="← Back", theme_text_color="Custom", text_color=ThemeConfig.GOLD_ACCENT, bold=True)
        )
        back_btn.bind(on_release=self._handle_back)
        header_bar.add_widget(back_btn)

        header_lbl = MDLabel(
            text="Recently Deleted",
            font_size="20sp",
            bold=True,
            theme_text_color="Custom",
            text_color=ThemeConfig.GOLD_ACCENT,
            size_hint=(1.0, 1.0)
        )
        header_bar.add_widget(header_lbl)
        layout.add_widget(header_bar)

        # Feed ScrollView
        scroll = MDScrollView(size_hint=(1.0, 1.0))
        self.deleted_list = MDBoxLayout(
            orientation="vertical",
            spacing="10dp",
            size_hint_y=None
        )
        self.deleted_list.bind(minimum_height=self.deleted_list.setter("height"))

        scroll.add_widget(self.deleted_list)
        layout.add_widget(scroll)

        self.add_widget(layout)
        self._render_feed()

    def _render_feed(self):
        self.deleted_list.clear_widgets()

        if not self.deleted_memories:
            empty_box = MDBoxLayout(
                orientation="vertical",
                spacing="8dp",
                padding="32dp",
                size_hint=(1.0, None),
                height="160dp"
            )
            empty_lbl = MDLabel(
                text="No deleted memories.\nItems you delete will appear here for recovery.",
                halign="center",
                font_size="14sp",
                theme_text_color="Custom",
                text_color=ThemeConfig.TEXT_SECONDARY
            )
            empty_box.add_widget(empty_lbl)
            self.deleted_list.add_widget(empty_box)
            return

        for mem in self.deleted_memories:
            card = self._create_deleted_row(mem)
            self.deleted_list.add_widget(card)

    def _create_deleted_row(self, memory: Memory) -> MDCard:
        card = MDCard(
            size_hint=(1.0, None),
            height="110dp" if self.confirming_delete_id == memory.id else "94dp",
            padding=["12dp", "10dp", "12dp", "10dp"],
            md_bg_color=ThemeConfig.CARD_BACKGROUND,
            radius=[10, 10, 10, 10]
        )
        box = MDBoxLayout(orientation="vertical", spacing="6dp")

        # Top Row: Title + Category badge
        top_row = MDBoxLayout(orientation="horizontal", size_hint_y=None, height="24dp")
        title_lbl = MDLabel(
            text=memory.title,
            font_size="14sp",
            bold=True,
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_PRIMARY,
            size_hint=(0.7, 1.0)
        )
        cat_lbl = MDLabel(
            text=memory.category,
            font_size="11sp",
            halign="right",
            theme_text_color="Custom",
            text_color=ThemeConfig.GOLD_ACCENT,
            size_hint=(0.3, 1.0)
        )
        top_row.add_widget(title_lbl)
        top_row.add_widget(cat_lbl)
        box.add_widget(top_row)

        # Meta Subtitle: Retention + Deletion date
        deleted_date_str = str(memory.deleted_at)[:10] if memory.deleted_at else "Recently"
        human_del = DateNormalizer.format_human_date(deleted_date_str)
        meta_lbl = MDLabel(
            text=f"Retention: {memory.retention} · Deleted: {human_del}",
            font_size="11sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_SECONDARY,
            size_hint_y=None,
            height="18dp"
        )
        box.add_widget(meta_lbl)

        # Confirmation State
        if self.confirming_delete_id == memory.id:
            confirm_row = MDBoxLayout(orientation="horizontal", spacing="8dp", size_hint_y=None, height="32dp")
            c_lbl = MDLabel(
                text="Delete forever?",
                font_size="11sp",
                bold=True,
                theme_text_color="Custom",
                text_color=(0.9, 0.2, 0.2, 1),
                size_hint=(0.4, 1.0)
            )
            yes_btn = MDButton(style="elevated", size_hint=(0.3, 1.0))
            yes_btn.md_bg_color = (0.9, 0.2, 0.2, 1)
            yes_btn.add_widget(MDButtonText(text="Yes", bold=True, theme_text_color="Custom", text_color=(1, 1, 1, 1), font_size="11sp"))
            yes_btn.bind(on_release=lambda instance, m=memory: self._handle_confirm_delete_forever(m))

            no_btn = MDButton(style="outlined", size_hint=(0.3, 1.0))
            no_btn.add_widget(MDButtonText(text="Cancel", theme_text_color="Custom", text_color=ThemeConfig.TEXT_PRIMARY, font_size="11sp"))
            no_btn.bind(on_release=self._cancel_confirm_delete_forever)

            confirm_row.add_widget(c_lbl)
            confirm_row.add_widget(yes_btn)
            confirm_row.add_widget(no_btn)
            box.add_widget(confirm_row)
        else:
            # Action Buttons Row: [ Restore ] [ Delete Forever ]
            action_row = MDBoxLayout(orientation="horizontal", spacing="8dp", size_hint_y=None, height="30dp")
            
            restore_btn = MDButton(style="elevated", size_hint=(0.5, 1.0))
            restore_btn.md_bg_color = ThemeConfig.GOLD_ACCENT
            restore_btn.add_widget(
                MDButtonText(text="↩ Restore", bold=True, theme_text_color="Custom", text_color=(1, 1, 1, 1), font_size="11sp")
            )
            restore_btn.bind(on_release=lambda instance, m=memory: self._handle_restore(m))
            action_row.add_widget(restore_btn)

            df_btn = MDButton(style="outlined", size_hint=(0.5, 1.0))
            df_btn.add_widget(
                MDButtonText(text="🗑️ Delete Forever", theme_text_color="Custom", text_color=(0.9, 0.2, 0.2, 1), font_size="11sp")
            )
            df_btn.bind(on_release=lambda instance, m=memory: self._show_confirm_delete_forever(m))
            action_row.add_widget(df_btn)

            box.add_widget(action_row)

        card.add_widget(box)
        return card

    def _handle_restore(self, memory: Memory):
        if self.on_restore_cb:
            self.on_restore_cb(memory)

    def _show_confirm_delete_forever(self, memory: Memory):
        self.confirming_delete_id = memory.id
        self._render_feed()

    def _cancel_confirm_delete_forever(self, *args):
        self.confirming_delete_id = None
        self._render_feed()

    def _handle_confirm_delete_forever(self, memory: Memory):
        if self.on_delete_forever_cb:
            self.on_delete_forever_cb(memory)

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
