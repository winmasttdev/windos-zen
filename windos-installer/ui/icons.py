"""Inline SVG icons for the windOS Zen installer.

Branding is taken from the official windOS site (https://windos.nn1kk00.ru/):
    accent  blue   #3B82F6
    accent2 purple #8B5CF6
    slate text     #F4F4F5 / #A1A1AA
Everything is drawn as vector graphics so the binary ships with zero
external image dependencies.
"""
from PySide6.QtGui import QIcon, QPixmap, QPainter
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtCore import Qt, QByteArray, QSize

# site palette ----------------------------------------------------- #
ACCENT = "#3B82F6"
ACCENT2 = "#8B5CF6"
TEXT = "#F4F4F5"
DIM = "#A1A1AA"


def svg_to_pixmap(svg: str, size: int = 24) -> QPixmap:
    renderer = QSvgRenderer(QByteArray(svg.encode("utf-8")))
    pm = QPixmap(size, size)
    pm.fill(Qt.transparent)
    painter = QPainter(pm)
    painter.setRenderHint(QPainter.Antialiasing)
    painter.setRenderHint(QPainter.SmoothPixmapTransform)
    renderer.render(painter)
    painter.end()
    return pm


def svg_to_icon(svg: str, size: int = 24) -> QIcon:
    return QIcon(svg_to_pixmap(svg, size))


# ------------------------------------------------------------------ #
# Official windOS logo: blue circle + white wind swoosh
_LOGO = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<circle cx="12" cy="12" r="11" fill="{ACCENT}"/>
<path d="M18.42,9.22A7,7,0,0,0,5.06,10.61,4,4,0,0,0,6,18.5H18a4,4,0,0,0,.42-8Z" fill="#ffffff"/>
</svg>""".replace("{ACCENT}", ACCENT)

_DISK = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<rect x="2.5" y="6" width="19" height="12" rx="2.5" fill="#1a1a1a" stroke="{ACCENT}" stroke-width="1.4"/>
<circle cx="12" cy="12" r="3.1" fill="{ACCENT}"/>
<circle cx="12" cy="12" r="1.1" fill="#0B1120"/>
<rect x="5" y="9" width="2" height="6" rx="1" fill="{ACCENT2}"/>
<rect x="17" y="9" width="2" height="6" rx="1" fill="{ACCENT2}"/>
</svg>""".replace("{ACCENT}", ACCENT).replace("{ACCENT2}", ACCENT2)

_USER = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<circle cx="12" cy="8" r="4" fill="{ACCENT}"/>
<path d="M4 20c0-4.4 3.6-7 8-7s8 2.6 8 7z" fill="{ACCENT2}"/>
</svg>""".replace("{ACCENT}", ACCENT).replace("{ACCENT2}", ACCENT2)

_SUMMARY = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<rect x="4" y="3.5" width="16" height="17" rx="2" fill="#1a1a1a" stroke="{ACCENT}" stroke-width="1.3"/>
<rect x="7" y="7" width="10" height="1.8" rx="0.9" fill="{ACCENT}"/>
<rect x="7" y="11" width="10" height="1.8" rx="0.9" fill="{ACCENT2}"/>
<rect x="7" y="15" width="6.5" height="1.8" rx="0.9" fill="#3f3f46"/>
</svg>""".replace("{ACCENT}", ACCENT).replace("{ACCENT2}", ACCENT2)

_INSTALL = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path d="M12 3l3.5 4h-2.5v6h-2V7H8.5z" fill="{ACCENT}"/>
<rect x="5" y="15" width="14" height="3.2" rx="1.2" fill="{ACCENT2}"/>
<rect x="7.5" y="19" width="9" height="2.2" rx="1.1" fill="#3f3f46"/>
</svg>""".replace("{ACCENT}", ACCENT).replace("{ACCENT2}", ACCENT2)

_CHECK = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<circle cx="12" cy="12" r="9.2" fill="#10B981"/>
<path d="M7.5 12.4l3 3 6-6.2" fill="none" stroke="#050505" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
</svg>"""

_WARN = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path d="M12 3l9 16H3z" fill="#F59E0B"/>
<rect x="11" y="9" width="2" height="5" rx="1" fill="#050505"/>
<rect x="11" y="15.4" width="2" height="2" rx="1" fill="#050505"/>
</svg>"""


def icon_windos(size: int = 24):  return svg_to_icon(_LOGO, size)
def icon_disk(size: int = 24):    return svg_to_icon(_DISK, size)
def icon_user(size: int = 24):    return svg_to_icon(_USER, size)
def icon_summary(size: int = 24): return svg_to_icon(_SUMMARY, size)
def icon_install(size: int = 24): return svg_to_icon(_INSTALL, size)
def icon_check(size: int = 24):   return svg_to_icon(_CHECK, size)
def icon_warn(size: int = 24):    return svg_to_icon(_WARN, size)
