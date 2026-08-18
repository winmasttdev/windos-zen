"""Inline SVG icons for the windOS Zen installer.

Everything is drawn as vector graphics so the binary ships with zero
external image dependencies. Colors use the brand palette:
    neon cyan   #38BDF8
    indigo      #6366F1
    slate       #0F172A / #1E293B
"""
from PySide6.QtGui import QIcon, QPixmap, QPainter
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtCore import Qt, QByteArray, QSize


def svg_to_pixmap(svg: str, size: int = 24) -> QPixmap:
    renderer = QSvgRenderer(QByteArray(svg.encode("utf-8")))
    pm = QPixmap(size, size)
    pm.fill(Qt.transparent)
    painter = QPainter(pm)
    painter.setRenderHint(QPainter.Antialiasing)
    renderer.render(painter)
    painter.end()
    return pm


def svg_to_icon(svg: str, size: int = 24) -> QIcon:
    return QIcon(svg_to_pixmap(svg, size))


# ------------------------------------------------------------------ #
_WINDOS = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<rect x="3" y="3" width="8.2" height="8.2" rx="1.6" fill="#38BDF8"/>
<rect x="12.8" y="3" width="8.2" height="8.2" rx="1.6" fill="#6366F1"/>
<rect x="3" y="12.8" width="8.2" height="8.2" rx="1.6" fill="#6366F1"/>
<rect x="12.8" y="12.8" width="8.2" height="8.2" rx="1.6" fill="#38BDF8"/>
</svg>"""

_DISK = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<rect x="2.5" y="6" width="19" height="12" rx="2.5" fill="#1E293B" stroke="#38BDF8" stroke-width="1.4"/>
<circle cx="12" cy="12" r="3.1" fill="#38BDF8"/>
<circle cx="12" cy="12" r="1.1" fill="#0F172A"/>
<rect x="5" y="9" width="2" height="6" rx="1" fill="#6366F1"/>
<rect x="17" y="9" width="2" height="6" rx="1" fill="#6366F1"/>
</svg>"""

_USER = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<circle cx="12" cy="8" r="4" fill="#38BDF8"/>
<path d="M4 20c0-4.4 3.6-7 8-7s8 2.6 8 7z" fill="#6366F1"/>
</svg>"""

_SUMMARY = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<rect x="4" y="3.5" width="16" height="17" rx="2" fill="#1E293B" stroke="#38BDF8" stroke-width="1.3"/>
<rect x="7" y="7" width="10" height="1.8" rx="0.9" fill="#38BDF8"/>
<rect x="7" y="11" width="10" height="1.8" rx="0.9" fill="#6366F1"/>
<rect x="7" y="15" width="6.5" height="1.8" rx="0.9" fill="#475569"/>
</svg>"""

_INSTALL = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path d="M12 3l3.5 4h-2.5v6h-2V7H8.5z" fill="#38BDF8"/>
<rect x="5" y="15" width="14" height="3.2" rx="1.2" fill="#6366F1"/>
<rect x="7.5" y="19" width="9" height="2.2" rx="1.1" fill="#475569"/>
</svg>"""

_CHECK = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<circle cx="12" cy="12" r="9.2" fill="#22C55E"/>
<path d="M7.5 12.4l3 3 6-6.2" fill="none" stroke="#0F172A" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
</svg>"""

_WARN = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path d="M12 3l9 16H3z" fill="#F59E0B"/>
<rect x="11" y="9" width="2" height="5" rx="1" fill="#0F172A"/>
<rect x="11" y="15.4" width="2" height="2" rx="1" fill="#0F172A"/>
</svg>"""


def icon_windos(size: int = 24):  return svg_to_icon(_WINDOS, size)
def icon_disk(size: int = 24):    return svg_to_icon(_DISK, size)
def icon_user(size: int = 24):    return svg_to_icon(_USER, size)
def icon_summary(size: int = 24): return svg_to_icon(_SUMMARY, size)
def icon_install(size: int = 24): return svg_to_icon(_INSTALL, size)
def icon_check(size: int = 24):   return svg_to_icon(_CHECK, size)
def icon_warn(size: int = 24):    return svg_to_icon(_WARN, size)
