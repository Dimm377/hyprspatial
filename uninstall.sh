#!/usr/bin/env bash
# ==============================================================================
# Uninstaller for hypr-display-switcher
# Cleans up symlinks and restores backups
# ==============================================================================

set -euo pipefail

# ANSI Color Codes
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_QS_FILE="$HOME/.config/hypr/display-switcher/DisplaySwitcher.qml"
TARGET_QS_DIR="$HOME/.config/hypr/display-switcher"
TARGET_SCRIPT_FILE="$HOME/.config/hypr/scripts/toggle-presentation.sh"

echo -e "${BOLD}${BLUE}==> Starting hypr-display-switcher uninstaller...${NC}\n"

unlink_and_restore() {
    local target="$1"
    local base
    base="$(basename "$target")"

    if [ -L "$target" ]; then
        local current_target
        current_target="$(readlink -f "$target" 2>/dev/null || true)"
        if [[ "$current_target" == "$REPO_DIR"* ]]; then
            rm -f "$target"
            echo -e "  ${GREEN}[✓]${NC} Removed symlink: ${BLUE}$target${NC}"
        else
            echo -e "  ${YELLOW}[!]${NC} Skipping symlink pointing elsewhere: ${YELLOW}$target${NC}"
            return
        fi
    elif [ -e "$target" ]; then
        echo -e "  ${YELLOW}[!]${NC} Skipping regular file: ${YELLOW}$target${NC}"
        return
    else
        echo -e "  ${BLUE}[-]${NC} File not found: ${BLUE}$target${NC}"
        return
    fi

    # Check for latest backup to restore
    local latest_bak
    latest_bak=$(ls -1t "${target}.bak."* 2>/dev/null | head -n 1 || true)
    if [ -n "$latest_bak" ] && [ -f "$latest_bak" ]; then
        echo -e "  ${GREEN}[✓]${NC} Restoring backup from: ${GREEN}$latest_bak${NC}"
        mv "$latest_bak" "$target"
    fi
}

unlink_and_restore "$TARGET_QS_FILE"
unlink_and_restore "$TARGET_QS_DIR/ConfirmDialog.qml"
unlink_and_restore "$TARGET_QS_DIR/components"
unlink_and_restore "$TARGET_SCRIPT_FILE"

# Clean up display-switcher directory if empty
if [ -d "$TARGET_QS_DIR" ] && [ -z "$(ls -A "$TARGET_QS_DIR" 2>/dev/null)" ]; then
    rmdir "$TARGET_QS_DIR"
    echo -e "  ${GREEN}[✓]${NC} Removed empty directory: ${BLUE}$TARGET_QS_DIR${NC}"
fi

echo -e "\n${BOLD}${GREEN}==> Uninstallation complete!${NC}"
echo -e "${YELLOW}Remember to remove or comment out any display switcher keybinds in your Hyprland config.${NC}\n"
