"""
Custom Navigation Bar Component for MindBurst
Golden-white styled 3-tab bottom navigation (Burst, All, Ask).
"""
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.button import MDIconButton
from kivymd.uix.label import MDLabel
from kivymd.uix.card import MDCard
from kivy.uix.behaviors import ButtonBehavior
from kivy.graphics import Color, Rectangle, Line
from mindburst.ui.theme.theme_config import ThemeConfig

class NavTabItem(ButtonBehavior, MDBoxLayout):
    def __init__(self, tab_id: str, icon_text: str, label_text: str, on_select_cb, **kwargs):
        super().__init__(**kwargs)
        self.tab_id = tab_id
        self.on_select_cb = on_select_cb
        self.orientation = "vertical"
        self.spacing = "2dp"
        self.padding = ["8dp", "6dp", "8dp", "6dp"]
        self.size_hint_x = 1.0

        self.icon_label = MDLabel(
            text=icon_text,
            halign="center",
            font_size="20sp",
            size_hint_y=None,
            height="24dp"
        )
        self.text_label = MDLabel(
            text=label_text,
            halign="center",
            font_size="12sp",
            theme_text_color="Custom",
            text_color=ThemeConfig.TEXT_SECONDARY,
            size_hint_y=None,
            height="18dp"
        )

        self.add_widget(self.icon_label)
        self.add_widget(self.text_label)

    def on_press(self):
        if self.on_select_cb:
            self.on_select_cb(self.tab_id)

    def set_active(self, active: bool):
        if active:
            self.text_label.text_color = ThemeConfig.GOLD_ACCENT
            self.text_label.bold = True
        else:
            self.text_label.text_color = ThemeConfig.TEXT_SECONDARY
            self.text_label.bold = False


class MindBurstNavBar(MDBoxLayout):
    def __init__(self, on_tab_switch_callback, **kwargs):
        super().__init__(**kwargs)
        self.on_tab_switch_callback = on_tab_switch_callback
        self.orientation = "horizontal"
        self.size_hint_y = None
        self.height = "64dp"
        self.padding = ["12dp", "4dp", "12dp", "4dp"]
        self.spacing = "8dp"

        # Draw white background with top golden border
        with self.canvas.before:
            Color(*ThemeConfig.CARD_BACKGROUND)
            self.rect = Rectangle(pos=self.pos, size=self.size)
            Color(*ThemeConfig.GOLD_BORDER)
            self.border = Line(points=[self.x, self.y + self.height, self.x + self.width, self.y + self.height], width=1)

        self.bind(pos=self._update_canvas, size=self._update_canvas)

        # 3 Tabs
        self.burst_tab = NavTabItem("burst", "💥", "Burst", self._on_tab_click)
        self.all_tab = NavTabItem("all", "🧠", "All", self._on_tab_click)
        self.ask_tab = NavTabItem("ask", "🔎", "Ask", self._on_tab_click)

        self.add_widget(self.burst_tab)
        self.add_widget(self.all_tab)
        self.add_widget(self.ask_tab)

        self.tabs = {
            "burst": self.burst_tab,
            "all": self.all_tab,
            "ask": self.ask_tab,
        }
        self.set_active("burst")

    def _update_canvas(self, *args):
        self.rect.pos = self.pos
        self.rect.size = self.size
        self.border.points = [self.x, self.y + self.height, self.x + self.width, self.y + self.height]

    def _on_tab_click(self, tab_id: str):
        self.set_active(tab_id)
        if self.on_tab_switch_callback:
            self.on_tab_switch_callback(tab_id)

    def set_active(self, active_tab_id: str):
        for tab_id, tab_widget in self.tabs.items():
            tab_widget.set_active(tab_id == active_tab_id)
