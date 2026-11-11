#!/usr/bin/env bash
# Installs both Tsunyx Launcher variants on a fresh KDE Plasma 6 machine:
#   - local.tsunyxlauncher: the original, fullscreen paginated grid
#   - local.tsunyxdialog:   fixed-size, custom-bordered PlasmaCore.Dialog
#                           fork (see kwin-script-tsunyxdialog's own
#                           comments for why it needs its own KWin script)
# For each: symlinks the plasmoid into the user's local plasmoids dir,
# compiles + installs its Spanish translation catalog, and installs +
# enables its companion KWin script.
# After running this, add each widget to a panel by hand (right-click panel
# > Add Widgets > search for "Tsunyx Launcher") — that step isn't
# scriptable safely.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_kwin_script() {
    local src="$1" id="$2"
    echo "==> Installing KWin script: $id"
    if kpackagetool6 --type=KWin/Script --list 2>/dev/null | grep -q "^$id$"; then
        kpackagetool6 --type=KWin/Script --upgrade "$src"
    else
        kpackagetool6 --type=KWin/Script --install "$src"
    fi
    echo "==> Enabling KWin script: $id"
    kwriteconfig6 --file kwinrc --group Plugins --key "${id}Enabled" true
}

# --- Tsunyx Launcher (original, fullscreen) ---
PLASMOID_SRC="$REPO_DIR/local.tsunyxlauncher"
PLASMOID_DEST="$HOME/.local/share/plasma/plasmoids/local.tsunyxlauncher"
PO_FILE="$PLASMOID_SRC/contents/locale/es/LC_MESSAGES/plasma_applet_local.tsunyxlauncher.po"
MO_DEST="$HOME/.local/share/locale/es/LC_MESSAGES/plasma_applet_local.tsunyxlauncher.mo"

echo "==> Linking plasmoid into $PLASMOID_DEST"
mkdir -p "$(dirname "$PLASMOID_DEST")"
if [ -L "$PLASMOID_DEST" ] || [ -e "$PLASMOID_DEST" ]; then
    echo "    already exists, leaving it as-is (remove it first to relink)"
else
    ln -s "$PLASMOID_SRC" "$PLASMOID_DEST"
fi

echo "==> Compiling Spanish translation catalog"
mkdir -p "$(dirname "$MO_DEST")"
msgfmt "$PO_FILE" -o "$MO_DEST"

install_kwin_script "$REPO_DIR/kwin-script-skip-taskbar" "tsunyxlauncherskiptaskbar"

# --- Tsunyx Launcher (Dialog fork, fixed-size bordered) ---
DIALOG_PLASMOID_SRC="$REPO_DIR/local.tsunyxdialog"
DIALOG_PLASMOID_DEST="$HOME/.local/share/plasma/plasmoids/local.tsunyxdialog"
DIALOG_PO_FILE="$DIALOG_PLASMOID_SRC/contents/locale/es/LC_MESSAGES/plasma_applet_local.tsunyxdialog.po"
DIALOG_MO_DEST="$HOME/.local/share/locale/es/LC_MESSAGES/plasma_applet_local.tsunyxdialog.mo"

echo "==> Linking plasmoid into $DIALOG_PLASMOID_DEST"
mkdir -p "$(dirname "$DIALOG_PLASMOID_DEST")"
if [ -L "$DIALOG_PLASMOID_DEST" ] || [ -e "$DIALOG_PLASMOID_DEST" ]; then
    echo "    already exists, leaving it as-is (remove it first to relink)"
else
    ln -s "$DIALOG_PLASMOID_SRC" "$DIALOG_PLASMOID_DEST"
fi

echo "==> Compiling Spanish translation catalog"
mkdir -p "$(dirname "$DIALOG_MO_DEST")"
msgfmt "$DIALOG_PO_FILE" -o "$DIALOG_MO_DEST"

install_kwin_script "$REPO_DIR/kwin-script-tsunyxdialog" "tsunyxdialogcenter"

echo "==> Reloading KWin config"
qdbus6 org.kde.KWin /KWin reconfigure

echo "==> Done. Add each widget from a panel's right-click menu > Add Widgets > search for \"Tsunyx Launcher\"."
