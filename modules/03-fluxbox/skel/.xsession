#!/bin/sh
# windOS Zen — X session entry point (lightdm "default" and startx both land here)
export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
# NOTE: no QT_QPA_PLATFORM_THEME here — qt5ct/qt6ct are not installed;
# a dangling theme name breaks Qt app startup (incl. the installer).
export _JAVA_AWT_WM_NONREPARENTING=1
# browsers: respect our low-RAM world
export MOZ_DISABLE_CONTENT_SANDBOX=0
exec fluxbox-start
