"""windOS Zen installer visual theme (Qt StyleSheet).

Palette and type mirror the official windOS site
(https://windos.nn1kk00.ru/): bright-blue accent, purple secondary,
near-black surfaces, Plus Jakarta Sans.
"""
from PySide6.QtGui import QColor

# Brand palette (from windos.nn1kk00.ru) --------------------------- #
ACCENT = "#3B82F6"      # bright blue
ACCENT2 = "#8B5CF6"     # purple
BG_DEEP = "#050505"     # site darkBg
BG_PANEL = "#121212"    # site darkCard
BG_CARD = "#18181B"
BORDER = "#27272A"      # site darkBorder
TEXT = "#F4F4F5"
TEXT_DIM = "#A1A1AA"
DANGER = "#EF4444"
SUCCESS = "#10B981"

FONT = "'Plus Jakarta Sans', 'Segoe UI', system-ui, 'Noto Sans', sans-serif"

WINDOS_STYLESHEET = f"""
* {{
    font-family: {FONT};
    color: {TEXT};
}}
QLabel {{
    background: transparent;
}}
QMainWindow {{
    background: {BG_DEEP};
}}
#Header {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 {ACCENT}, stop:1 {ACCENT2});
}}
#HeaderTitle {{
    font-size: 18px; font-weight: 800; color: #ffffff;
}}
#ModeBadge {{
    font-size: 11px; font-weight: 800; letter-spacing: 1px;
    color: #ffffff; background: rgba(255,255,255,0.22);
    border-radius: 999px; padding: 4px 12px;
}}
#ModeBadge[live="true"] {{
    color: #fff; background: {DANGER};
}}
#Sidebar {{
    background: {BG_PANEL};
    border-right: 1px solid {BORDER};
    min-width: 200px; max-width: 200px;
}}
#StepItem {{
    border-radius: 10px; padding: 8px 10px;
}}
#StepItem[state="idle"] {{ background: transparent; }}
#StepItem[state="active"] {{
    background: {BG_CARD}; border: 1px solid {ACCENT};
}}
#StepItem[state="done"] {{ background: {BG_CARD}; }}
#StepLabel {{ font-size: 14px; color: {TEXT_DIM}; }}
#StepLabel[state="active"] {{ color: #ffffff; font-weight: 700; }}
#StepLabel[state="done"] {{ color: {ACCENT}; font-weight: 600; }}

QFrame#Card {{
    background: {BG_CARD}; border: 1px solid {BORDER};
    border-radius: 16px;
}}
QLabel#PageTitle {{
    font-size: 24px; font-weight: 800; color: #ffffff;
}}
QLabel#PageSub {{
    font-size: 13px; color: {TEXT_DIM};
}}
QLabel#FieldLabel {{
    font-size: 12px; color: {TEXT_DIM}; padding-bottom: 4px;
}}
QLineEdit, QComboBox {{
    background: transparent; border: 1px solid {BORDER};
    border-radius: 10px; padding: 10px 12px; font-size: 14px;
    color: {TEXT};
}}
QLineEdit:focus, QComboBox:focus {{ border: 1px solid {ACCENT}; }}
QLineEdit[invalid="true"] {{ border: 1px solid {DANGER}; }}
QComboBox QAbstractItemView {{
    background: {BG_DEEP}; color: {TEXT};
    selection-background-color: {ACCENT};
}}

QPushButton#PrimaryButton {{
    background: qlineargradient(x1:0,y1:0,x2:1,y2:0,
        stop:0 {ACCENT}, stop:1 {ACCENT2});
    color: #ffffff; font-weight: 700; font-size: 14px;
    border-radius: 10px; padding: 11px 24px; border: none;
}}
QPushButton#PrimaryButton:hover {{ opacity: 0.92; }}
QPushButton#DangerButton {{
    background: {DANGER}; color: #fff; font-weight: 700;
    font-size: 14px; border-radius: 10px; padding: 11px 24px; border: none;
}}
QPushButton#DangerButton:hover {{ background: #f87171; }}
QPushButton#GhostButton {{
    background: transparent; color: {TEXT_DIM};
    border: 1px solid {BORDER}; border-radius: 10px;
    padding: 11px 22px; font-size: 14px;
}}
QPushButton#GhostButton:hover {{ color: #ffffff; border: 1px solid {ACCENT}; }}
QPushButton:disabled {{ opacity: 0.4; }}

QTextEdit#Log {{
    background: #0a0a0a; color: #7DD3FC; border: 1px solid {BORDER};
    border-radius: 12px; font-family: 'JetBrains Mono', 'Consolas', monospace;
    font-size: 12px; padding: 12px;
}}
QProgressBar {{
    background: {BG_DEEP}; border: 1px solid {BORDER};
    border-radius: 8px; height: 16px; text-align: center;
    color: {TEXT};
}}
QProgressBar::chunk {{
    background: qlineargradient(x1:0,y1:0,x2:1,y2:0,
        stop:0 {ACCENT}, stop:1 {ACCENT2});
    border-radius: 7px;
}}
#NavBar {{
    background: {BG_PANEL}; border-top: 1px solid {BORDER};
}}
"""
