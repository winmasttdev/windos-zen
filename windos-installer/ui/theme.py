"""windOS Zen installer visual theme (Qt StyleSheet)."""
from PySide6.QtGui import QColor

# Brand palette ----------------------------------------------------- #
BRAND_CYAN = "#38BDF8"
BRAND_INDIGO = "#6366F1"
BG_DEEP = "#0B1120"
BG_PANEL = "#0F172A"
BG_CARD = "#151E2E"
BORDER = "#223049"
TEXT = "#E2E8F0"
TEXT_DIM = "#94A3B8"
DANGER = "#F43F5E"
SUCCESS = "#22C55E"

WINDOS_STYLESHEET = f"""
* {{
    font-family: 'Segoe UI', 'Noto Sans', system-ui, sans-serif;
    color: {TEXT};
}}
QMainWindow, QWidget {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
        stop:0 {BG_DEEP}, stop:1 #0A0F1C);
}}
#Header {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 {BRAND_INDIGO}, stop:1 {BRAND_CYAN});
}}
#HeaderTitle {{
    font-size: 18px; font-weight: 700; color: #0B1120;
}}
#ModeBadge {{
    font-size: 11px; font-weight: 700; letter-spacing: 1px;
    color: #0B1120; background: rgba(255,255,255,0.25);
    border-radius: 6px; padding: 3px 10px;
}}
#ModeBadge[live="true"] {{
    color: #fff; background: {DANGER};
}}
#Sidebar {{
    background: {BG_PANEL};
    border-right: 1px solid {BORDER};
    min-width: 190px; max-width: 190px;
}}
#StepItem {{
    border-radius: 8px; padding: 6px 8px;
}}
#StepItem[state="idle"] {{ background: transparent; }}
#StepItem[state="active"] {{
    background: {BG_CARD}; border: 1px solid {BRAND_CYAN};
}}
#StepItem[state="done"] {{ background: {BG_CARD}; }}
#StepLabel {{ font-size: 14px; color: {TEXT_DIM}; }}
#StepLabel[state="active"] {{ color: {TEXT}; font-weight: 700; }}
#StepLabel[state="done"] {{ color: {BRAND_CYAN}; font-weight: 600; }}

QFrame#Card {{
    background: {BG_CARD}; border: 1px solid {BORDER};
    border-radius: 14px;
}}
QLabel#PageTitle {{
    font-size: 22px; font-weight: 700; color: {TEXT};
}}
QLabel#PageSub {{
    font-size: 13px; color: {TEXT_DIM};
}}
QLabel#FieldLabel {{
    font-size: 12px; color: {TEXT_DIM}; padding-bottom: 2px;
}}
QLineEdit, QComboBox {{
    background: {BG_DEEP}; border: 1px solid {BORDER};
    border-radius: 8px; padding: 9px 11px; font-size: 14px;
}}
QLineEdit:focus, QComboBox:focus {{
    border: 1px solid {BRAND_CYAN};
}}
QLineEdit[invalid="true"] {{
    border: 1px solid {DANGER};
}}
QComboBox QAbstractItemView {{
    background: {BG_DEEP}; selection-background-color: {BRAND_INDIGO};
}}

QPushButton#PrimaryButton {{
    background: qlineargradient(x1:0,y1:0,x2:1,y2:0,
        stop:0 {BRAND_CYAN}, stop:1 {BRAND_INDIGO});
    color: #0B1120; font-weight: 700; font-size: 14px;
    border-radius: 9px; padding: 10px 22px; border: none;
}}
QPushButton#PrimaryButton:hover {{ opacity: 0.9; }}
QPushButton#DangerButton {{
    background: {DANGER}; color: #fff; font-weight: 700;
    font-size: 14px; border-radius: 9px; padding: 10px 22px; border: none;
}}
QPushButton#DangerButton:hover {{ background: #fb7185; }}
QPushButton#GhostButton {{
    background: transparent; color: {TEXT_DIM};
    border: 1px solid {BORDER}; border-radius: 9px;
    padding: 10px 20px; font-size: 14px;
}}
QPushButton#GhostButton:hover {{ color: {TEXT}; border: 1px solid {BRAND_CYAN}; }}
QPushButton:disabled {{ opacity: 0.4; }}

QTextEdit#Log {{
    background: #060A12; color: #7DD3FC; border: 1px solid {BORDER};
    border-radius: 10px; font-family: 'JetBrains Mono', 'Consolas', monospace;
    font-size: 12px; padding: 10px;
}}
QProgressBar {{
    background: {BG_DEEP}; border: 1px solid {BORDER};
    border-radius: 8px; height: 16px; text-align: center;
}}
QProgressBar::chunk {{
    background: qlineargradient(x1:0,y1:0,x2:1,y2:0,
        stop:0 {BRAND_INDIGO}, stop:1 {BRAND_CYAN});
    border-radius: 7px;
}}
#NavBar {{
    background: {BG_PANEL}; border-top: 1px solid {BORDER};
}}
"""
