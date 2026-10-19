#!/usr/bin/env bash
# ==============================================================================
# Installer for hypr-display-switcher
# ==============================================================================

set -euo pipefail

# ANSI Color Codes
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_QS_DIR="$HOME/.config/hypr/display-switcher"
TARGET_SCRIPTS_DIR="$HOME/.config/hypr/scripts"

echo -e "${BOLD}${BLUE}==> Starting hypr-display-switcher installer...${NC}\n"

# ─── 1. Check Required Dependencies ───────────────────────────────────────────
echo -e "${BOLD}1. Checking required dependencies:${NC}"

MISSING_DEPS=()

check_dep() {
    local cmd="$1"
    local pkg_hint="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "  ${GREEN}[✓]${NC} Found ${BOLD}$cmd${NC}"
    else
        echo -e "  ${RED}[✗]${NC} Missing ${BOLD}$cmd${NC} ($pkg_hint)"
        MISSING_DEPS+=("$pkg_hint")
    fi
}

check_dep "hyprctl" "hyprland"
check_dep "quickshell" "quickshell"
check_dep "jq" "jq"
check_dep "notify-send" "libnotify"

# Optional check
if ! fc-list : family | grep -qi "nerd font"; then
    echo -e "  ${YELLOW}[!]${NC} Recommended: Nerd Font (e.g., ttf-cascadia-cove-nerd or any Nerd Font)"
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "\n${RED}${BOLD}Error: Missing required dependencies!${NC}"
    echo -e "Please install missing packages before continuing:\n"
    echo -e "  ${BOLD}Arch Linux:${NC}   sudo pacman -S ${MISSING_DEPS[*]}"
    echo -e "  ${BOLD}Fedora:${NC}       sudo dnf install ${MISSING_DEPS[*]}"
    echo -e "  ${BOLD}Ubuntu/Debian:${NC} sudo apt install ${MISSING_DEPS[*]}"
    echo ""
    exit 1
fi

echo -e "\n${GREEN}${BOLD}All dependencies satisfied!${NC}\n"

# ─── 2. Create Target Directories & Symlinks ──────────────────────────────────
echo -e "${BOLD}2. Setting up configuration & script symlinks:${NC}"

mkdir -p "$TARGET_QS_DIR" "$TARGET_SCRIPTS_DIR"

link_file() {
    local src="$1"
    local dest="$2"
    local base
    base="$(basename "$dest")"

    if [ -L "$dest" ]; then
        local current_target
        current_target="$(readlink -f "$dest")"
        if [ "$current_target" = "$src" ]; then
            echo -e "  ${GREEN}[✓]${NC} Symlink already in place: ${BLUE}$dest${NC}"
            return
        fi
    fi

    if [ -f "$dest" ] && [ ! -L "$dest" ]; then
        local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
        echo -e "  ${YELLOW}[!]${NC} Backing up existing $base to: ${YELLOW}$backup${NC}"
        mv "$dest" "$backup"
    fi

    ln -sfn "$src" "$dest"
    echo -e "  ${GREEN}[✓]${NC} Linked: ${BLUE}$dest${NC} -> ${GREEN}$src${NC}"
}

# Ensure script is executable
chmod +x "$REPO_DIR/scripts/toggle-presentation.sh"

link_file "$REPO_DIR/quickshell/DisplaySwitcher.qml" "$TARGET_QS_DIR/DisplaySwitcher.qml"
link_file "$REPO_DIR/quickshell/ConfirmDialog.qml" "$TARGET_QS_DIR/ConfirmDialog.qml"
link_file "$REPO_DIR/scripts/toggle-presentation.sh" "$TARGET_SCRIPTS_DIR/toggle-presentation.sh"

# ─── 3. Print Keybind Setup Instructions ──────────────────────────────────────
echo -e "\n${BOLD}${GREEN}==> Installation completed successfully!${NC}\n"
echo -e "${BOLD}3. Add keybinds to your Hyprland configuration:${NC}\n"

echo -e "${BOLD}Option A: Standard Hyprland config (~/.config/hypr/hyprland.conf)${NC}"
echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}"
cat << 'EOF'
# Display Switcher Studio Overlay
bind = $mainMod SHIFT, P, exec, ~/.config/hypr/scripts/toggle-presentation.sh --gui

# Quick Toggle Mirror / Extend
bind = $mainMod, P, exec, ~/.config/hypr/scripts/toggle-presentation.sh
bind = , XF86Display, exec, ~/.config/hypr/scripts/toggle-presentation.sh
EOF
echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}\n"

echo -e "${BOLD}Option B: Hyprland with Lua config (~/.config/hypr/config/keybinds.lua)${NC}"
echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}"
cat << 'EOF'
-- Display Switcher Studio Overlay
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/toggle-presentation.sh --gui"))

-- Quick Toggle Mirror / Extend
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/toggle-presentation.sh"))
hl.bind("XF86Display", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/toggle-presentation.sh"), { locked = true })
EOF
echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}\n"

echo -e "${BOLD}Test it right now with:${NC}"
echo -e "  ${GREEN}~/.config/hypr/scripts/toggle-presentation.sh --gui${NC}\n"
