#!/usr/bin/env bash
# ============================================================
# Hyprland Presentation & Display Switcher Script
# 100% Dynamic Hardware Detection & Multi-Position Extend Support
# Supports: Mirror, Extend (Left / Right / Top), Laptop Only, External Only, GUI
# ============================================================

MONS_JSON=$(hyprctl monitors all -j 2>/dev/null)
if [ -z "$MONS_JSON" ] || [ "$MONS_JSON" = "null" ]; then
    MONS_JSON=$(hyprctl monitors -j 2>/dev/null)
fi

# Detect Internal / Laptop display dynamically (eDP, LVDS, DSI)
LAPTOP_MON=$(echo "$MONS_JSON" | jq -r '.[] | select(.name | test("^(eDP|LVDS|DSI)")) | .name' | head -n 1)
if [ -z "$LAPTOP_MON" ] || [ "$LAPTOP_MON" = "null" ]; then
    LAPTOP_MON=$(echo "$MONS_JSON" | jq -r '.[0].name // empty')
fi

# Detect External display dynamically (first monitor that is not LAPTOP_MON)
EXT_MON=$(echo "$MONS_JSON" | jq -r --arg lap "$LAPTOP_MON" '.[] | select(.name != $lap) | .name' | head -n 1)

if [ -z "$EXT_MON" ] || [ "$EXT_MON" = "null" ]; then
    if [ "$1" != "--laptop-only" ] && [ "$1" != "--gui" ] && [ "$1" != "--menu" ]; then
        notify-send -u low -i video-display "Display Switcher" "Tidak ada proyektor / monitor eksternal terdeteksi."
        exit 0
    fi
fi

# Check whether Hyprland is using Lua parser or legacy config
IS_LUA=false
if hyprctl keyword dummy test 2>&1 | grep -q "non-legacy"; then
    IS_LUA=true
fi

# Dynamic highest resolution & refresh rate detection
get_best_mode() {
    local mon="$1"
    echo "$MONS_JSON" | jq -r --arg m "$mon" '
        .[] | select(.name == $m) |
        if (.availableModes and (.availableModes | length > 0)) then
            .availableModes | map(
                capture("(?<w>[0-9]+)x(?<h>[0-9]+)@(?<r>[0-9.]+)Hz") |
                {w: (.w|tonumber), h: (.h|tonumber), r: (.r|tonumber), orig: "\(.w)x\(.h)@\(.r)"}
            ) | sort_by(.w, .h, .r) | last | .orig
        elif .width and .height and .refreshRate then
            "\(.width)x\(.height)@\(.refreshRate | round)"
        else
            "preferred"
        end
    '
}

EXT_MODE=$(get_best_mode "$EXT_MON")
LAP_MODE=$(get_best_mode "$LAPTOP_MON")
[ -z "$EXT_MODE" ] || [ "$EXT_MODE" = "null" ] && EXT_MODE="preferred"
[ -z "$LAP_MODE" ] || [ "$LAP_MODE" = "null" ] && LAP_MODE="preferred"

# Dynamic monitor dimensions (fallback 1920x1080)
EXT_W=$(echo "$MONS_JSON" | jq -r --arg m "$EXT_MON" '.[] | select(.name == $m) | .width // 1920')
EXT_H=$(echo "$MONS_JSON" | jq -r --arg m "$EXT_MON" '.[] | select(.name == $m) | .height // 1080')
LAP_W=$(echo "$MONS_JSON" | jq -r --arg m "$LAPTOP_MON" '.[] | select(.name == $m) | .width // 1920')
LAP_H=$(echo "$MONS_JSON" | jq -r --arg m "$LAPTOP_MON" '.[] | select(.name == $m) | .height // 1080')

# Optional ICC profile handling (failsafe)
ICC_OPT=""
for candidate in \
    "$HOME/.config/hypr/profiles/${EXT_MON}_sRGB.icm" \
    "$HOME/.config/hypr/profiles/F24G41F_sRGB.icm" \
    "$HOME/.local/share/icc/${EXT_MON}.icm" \
    "$HOME/.local/share/icc/${EXT_MON}.icc"; do
    if [ -f "$candidate" ]; then
        ICC_OPT=", icc = '$candidate'"
        break
    fi
done

apply_mirror() {
    hyprctl dismissnotify -1 >/dev/null 2>&1
    if [ "$IS_LUA" = true ]; then
        hyprctl eval "hl.monitor({ output = '$EXT_MON', mode = 'preferred', position = 'auto', scale = 1.0, mirror = '$LAPTOP_MON', disabled = false })" >/dev/null 2>&1
        sleep 0.15
        hyprctl eval "hl.monitor({ output = '$LAPTOP_MON', mode = '$LAP_MODE', position = '0x0', scale = 1.0, disabled = false })" >/dev/null 2>&1
    else
        hyprctl keyword monitor "$EXT_MON, preferred, auto, 1, mirror, $LAPTOP_MON"
        sleep 0.15
        hyprctl keyword monitor "$LAPTOP_MON, $LAP_MODE, 0x0, 1"
    fi
    notify-send -u normal -i video-display "Display Mode" "📺 Mirror Mode (Duplicate)\nLayar $LAPTOP_MON diduplikasi ke $EXT_MON"
}

apply_extend() {
    local pos="${1:-left}"
    hyprctl dismissnotify -1 >/dev/null 2>&1

    case "$pos" in
        right)
            # Laptop at 0x0, External on Right at ${LAP_W}x0
            if [ "$IS_LUA" = true ]; then
                hyprctl eval "hl.monitor({ output = '$EXT_MON', mode = '$EXT_MODE', position = '${LAP_W}x0', scale = 1.0, mirror = '', disabled = false$ICC_OPT })" >/dev/null 2>&1
                sleep 0.15
                hyprctl eval "hl.monitor({ output = '$LAPTOP_MON', mode = '$LAP_MODE', position = '0x0', scale = 1.0, mirror = '', disabled = false })" >/dev/null 2>&1
            else
                hyprctl keyword monitor "$EXT_MON, $EXT_MODE, ${LAP_W}x0, 1"
                sleep 0.15
                hyprctl keyword monitor "$LAPTOP_MON, $LAP_MODE, 0x0, 1"
            fi
            notify-send -u normal -i video-display "Display Mode" "🖥️ Extend Mode (Right)\n$LAPTOP_MON di kiri (0x0) · $EXT_MON di kanan (${LAP_W}x0)"
            ;;
        top)
            # External at 0x0 (top), Laptop at 0x${EXT_H} (below)
            if [ "$IS_LUA" = true ]; then
                hyprctl eval "hl.monitor({ output = '$LAPTOP_MON', mode = '$LAP_MODE', position = '0x${EXT_H}', scale = 1.0, mirror = '', disabled = false })" >/dev/null 2>&1
                sleep 0.15
                hyprctl eval "hl.monitor({ output = '$EXT_MON', mode = '$EXT_MODE', position = '0x0', scale = 1.0, mirror = '', disabled = false$ICC_OPT })" >/dev/null 2>&1
            else
                hyprctl keyword monitor "$LAPTOP_MON, $LAP_MODE, 0x${EXT_H}, 1"
                sleep 0.15
                hyprctl keyword monitor "$EXT_MON, $EXT_MODE, 0x0, 1"
            fi
            notify-send -u normal -i video-display "Display Mode" "🖥️ Extend Mode (Top)\n$EXT_MON di atas (0x0) · $LAPTOP_MON di bawah (0x${EXT_H})"
            ;;
        left|*)
            # External on Left at 0x0, Laptop on Right at ${EXT_W}x0
            if [ "$IS_LUA" = true ]; then
                hyprctl eval "hl.monitor({ output = '$LAPTOP_MON', mode = '$LAP_MODE', position = '${EXT_W}x0', scale = 1.0, mirror = '', disabled = false })" >/dev/null 2>&1
                sleep 0.15
                hyprctl eval "hl.monitor({ output = '$EXT_MON', mode = '$EXT_MODE', position = '0x0', scale = 1.0, mirror = '', disabled = false$ICC_OPT })" >/dev/null 2>&1
            else
                hyprctl keyword monitor "$LAPTOP_MON, $LAP_MODE, ${EXT_W}x0, 1"
                sleep 0.15
                hyprctl keyword monitor "$EXT_MON, $EXT_MODE, 0x0, 1"
            fi
            notify-send -u normal -i video-display "Display Mode" "🖥️ Extend Mode (Left)\n$EXT_MON di kiri (0x0) · $LAPTOP_MON di kanan (${EXT_W}x0)"
            ;;
    esac
}

apply_laptop_only() {
    hyprctl dismissnotify -1 >/dev/null 2>&1
    if [ "$IS_LUA" = true ]; then
        if [ -n "$EXT_MON" ]; then
            hyprctl eval "hl.monitor({ output = '$EXT_MON', disabled = true })" >/dev/null 2>&1
            sleep 0.15
        fi
        hyprctl eval "hl.monitor({ output = '$LAPTOP_MON', mode = '$LAP_MODE', position = '0x0', scale = 1.0, disabled = false })" >/dev/null 2>&1
    else
        [ -n "$EXT_MON" ] && hyprctl keyword monitor "$EXT_MON, disable"
        sleep 0.15
        hyprctl keyword monitor "$LAPTOP_MON, $LAP_MODE, 0x0, 1"
    fi
    notify-send -u normal -i video-display "Display Mode" "💻 Laptop Only\nLayar $LAPTOP_MON aktif"
}

apply_projector_only() {
    if [ -z "$EXT_MON" ]; then
        notify-send -u low -i video-display "Display Switcher" "Tidak ada monitor eksternal terdeteksi."
        return
    fi
    hyprctl dismissnotify -1 >/dev/null 2>&1
    if [ "$IS_LUA" = true ]; then
        hyprctl eval "hl.monitor({ output = '$LAPTOP_MON', disabled = true })" >/dev/null 2>&1
        sleep 0.15
        hyprctl eval "hl.monitor({ output = '$EXT_MON', mode = '$EXT_MODE', position = '0x0', scale = 1.0, mirror = '', disabled = false$ICC_OPT })" >/dev/null 2>&1
    else
        hyprctl keyword monitor "$LAPTOP_MON, disable"
        sleep 0.15
        hyprctl keyword monitor "$EXT_MON, $EXT_MODE, 0x0, 1"
    fi
    notify-send -u normal -i video-display "Display Mode" "📽️ External Only\nLayar $LAPTOP_MON mati, monitor $EXT_MON ($EXT_MODE) aktif"
}

toggle_mirror_extend() {
    IS_MIRROR=$(echo "$MONS_JSON" | jq -r --arg m "$EXT_MON" '.[] | select(.name == $m) | .mirrorOf')
    if [ "$IS_MIRROR" != "none" ] && [ -n "$IS_MIRROR" ]; then
        apply_extend "left"
    else
        apply_mirror
    fi
}

toggle_gui() {
    local PID
    PID=$(pgrep -f "DisplaySwitcher\.qml" | head -n 1)
    if [ -n "$PID" ]; then
        kill "$PID" 2>/dev/null
    else
        quickshell -p "$HOME/.config/hypr/display-switcher/DisplaySwitcher.qml" >/dev/null 2>&1 &
    fi
}

show_menu() {
    toggle_gui
}

case "$1" in
    --mirror) apply_mirror ;;
    --extend) apply_extend "$2" ;;
    --extend-left) apply_extend "left" ;;
    --extend-right) apply_extend "right" ;;
    --extend-top) apply_extend "top" ;;
    --laptop-only) apply_laptop_only ;;
    --projector-only) apply_projector_only ;;
    --gui|--menu) toggle_gui ;;
    --toggle|"") toggle_mirror_extend ;;
    *) echo "Usage: $0 [--toggle | --gui | --mirror | --extend [left|right|top] | --laptop-only | --projector-only]" ;;
esac
