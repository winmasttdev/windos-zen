#!/usr/bin/env python3
"""windOS Zen native installer - entry point.

Launches the PySide6 graphical installer. Safe by default: runs in
dry-run (preview) mode unless explicitly switched to real mode inside
the UI. No disk writes happen unless a real installation is confirmed.

Usage:
    python -m windos_installer          # run as package
    python main.py                      # run directly
    QT_QPA_PLATFORM=offscreen python main.py   # headless / CI smoke test
"""
from .main import main

if __name__ == "__main__":
    main()
