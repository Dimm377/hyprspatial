#!/usr/bin/env bash
# Hyprland display switcher and presentation toggle

STATE_FILE="/tmp/hypr_display_switcher_prev_state.json"
CONFIRM_FILE="/tmp/hypr_display_confirmed"
WATCHDOG_PID_FILE="/tmp/hypr_display_watchdog.pid"
LOCK_FILE="/tmp/hypr_display_switcher.lock"

acquire_lock() {
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        echo "Display switch operation already in progress." >&2
        exit 0
    fi
}

NO_FAILSAFE=false
for arg in "$@"; do
    if [ "$arg" = "--no-failsafe" ]; then
        NO_FAILSAFE=true
    fi
done

MONS_JSON=$(hyprctl monitors all -j 2>/dev/null)
if [ -z "$MONS_JSON" ] || [ "$MONS_JSON" = "null" ]; then
    MONS_JSON=$(hyprctl monitors -j 2>/dev/null)
fi
if [ -z "$MONS_JSON" ] || [ "$MONS_JSON" = "null" ]; then
    MONS_JSON="[]"
fi

# Detect Internal / Laptop display dynamically (eDP, LVDS, DSI)
LAPTOP_MON=$(echo "$MONS_JSON" | jq -r '.[] | select(.name | test("^(eDP|LVDS|DSI)")) | .name' | head -n 1)
if [ -z "$LAPTOP_MON" ] || [ "$LAPTOP_MON" = "null" ]; then
    LAPTOP_MON=$(echo "$MONS_JSON" | jq -r '.[0].name // empty')
fi

# Detect External display dynamically (first monitor that is not LAPTOP_MON)
EXT_MON=$(echo "$MONS_JSON" | jq -r --arg lap "$LAPTOP_MON" '.[] | select(.name != $lap) | .name' | head -n 1)

# Check whether Hyprland is using Lua parser or legacy config
IS_LUA=false
if hyprctl keyword dummy test 2>&1 | grep -q "non-legacy"; then
    IS_LUA=true
fi

# Dynamic highest resolution & refresh rate detection
get_best_mode() {
    local mon="$1"
    if [ -z "$mon" ] || [ "$mon" = "null" ]; then
        echo "preferred"
        return
    fi
    echo "$MONS_JSON" | jq -r --arg m "$mon" '
        .[] | select(.name == $m) |
        if (.availableModes and (.availableModes | length > 0)) then
            ([.availableModes[] | capture("(?<w>[0-9]+)x(?<h>[0-9]+)@(?<r>[0-9.]+)Hz")? |
            {w: (.w|tonumber), h: (.h|tonumber), r: (.r|tonumber), orig: "\(.w)x\(.h)@\(.r)"}] |
            sort_by(.w, .h, .r) | last | .orig) // "preferred"
        elif .width and .height and .refreshRate then
            "\(.width)x\(.height)@\(.refreshRate | round)"
        else
            "preferred"
        end
    '
}

EXT_MODE=$(get_best_mode "$EXT_MON")
LAP_MODE=$(get_best_mode "$LAPTOP_MON")
if [ -z "$EXT_MODE" ] || [ "$EXT_MODE" = "null" ]; then
    EXT_MODE="preferred"
fi
if [ -z "$LAP_MODE" ] || [ "$LAP_MODE" = "null" ]; then
    LAP_MODE="preferred"
fi

# Dynamic monitor dimensions with robust fallbacks
EXT_W=$(echo "$MONS_JSON" | jq -r --arg m "$EXT_MON" '([.[] | select(.name == $m) | .width] | first) // 1920')
EXT_H=$(echo "$MONS_JSON" | jq -r --arg m "$EXT_MON" '([.[] | select(.name == $m) | .height] | first) // 1080')
LAP_W=$(echo "$MONS_JSON" | jq -r --arg m "$LAPTOP_MON" '([.[] | select(.name == $m) | .width] | first) // 1920')
LAP_H=$(echo "$MONS_JSON" | jq -r --arg m "$LAPTOP_MON" '([.[] | select(.name == $m) | .height] | first) // 1080')

EXT_W="${EXT_W:-1920}"
EXT_H="${EXT_H:-1080}"
LAP_W="${LAP_W:-1920}"
LAP_H="${LAP_H:-1080}"

# Optional ICC profile handling (failsafe)
ICC_OPT=""
if [ -n "$EXT_MON" ] && [ "$EXT_MON" != "null" ]; then
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
fi

save_previous_state() {
    # Only save if not already in an unconfirmed transition
    if [ ! -f "$STATE_FILE" ]; then
        echo "$MONS_JSON" > "$STATE_FILE"
    fi
}

start_failsafe() {
    if [ "$NO_FAILSAFE" = true ]; then
        rm -f "$STATE_FILE" "$CONFIRM_FILE"
        return 0
    fi

    # Kill any existing watchdog
    if [ -f "$WATCHDOG_PID_FILE" ]; then
        local old_pid
        old_pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null)
        [ -n "$old_pid" ] && kill "$old_pid" 2>/dev/null
        rm -f "$WATCHDOG_PID_FILE"
    fi

    # Launch background watchdog process
    nohup "$0" --watchdog 15 >/dev/null 2>&1 &

    # Launch Quickshell confirmation dialog
    pkill -f "ConfirmDialog\.qml" 2>/dev/null || true
    if [ -f "$HOME/.config/hypr/display-switcher/ConfirmDialog.qml" ]; then
        quickshell -p "$HOME/.config/hypr/display-switcher/ConfirmDialog.qml" >/dev/null 2>&1 &
    elif [ -f "$(dirname "$0")/../quickshell/ConfirmDialog.qml" ]; then
        quickshell -p "$(dirname "$0")/../quickshell/ConfirmDialog.qml" >/dev/null 2>&1 &
    fi
}

confirm_changes() {
    touch "$CONFIRM_FILE"
    if [ -f "$WATCHDOG_PID_FILE" ]; then
        local wpid
        wpid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null)
        [ -n "$wpid" ] && kill "$wpid" 2>/dev/null
        rm -f "$WATCHDOG_PID_FILE"
    fi
    rm -f "$STATE_FILE"
    pkill -f "ConfirmDialog\.qml" 2>/dev/null || true
    notify-send -u low -i video-display "Display Switcher" "Pengaturan monitor dikonfirmasi."
}

apply_revert() {
    acquire_lock
    if [ ! -f "$STATE_FILE" ]; then
        notify-send -u low -i video-display "Display Switcher" "Tidak ada riwayat konfigurasi sebelumnya."
        return 0
    fi
    local PREV_JSON
    PREV_JSON=$(cat "$STATE_FILE" 2>/dev/null)
    rm -f "$STATE_FILE" "$CONFIRM_FILE"
    if [ -f "$WATCHDOG_PID_FILE" ]; then
        local wpid
        wpid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null)
        [ -n "$wpid" ] && kill "$wpid" 2>/dev/null
        rm -f "$WATCHDOG_PID_FILE"
    fi
    pkill -f "ConfirmDialog\.qml" 2>/dev/null || true

    hyprctl dismissnotify -1 >/dev/null 2>&1
    if [ "$IS_LUA" = true ]; then
        echo "$PREV_JSON" | jq -r '
          .[] |
          if .disabled then
            "hl.monitor({ output = \"" + .name + "\", disabled = true })"
          elif (.mirrorOf != "none" and (.mirrorOf | length > 0)) then
            "hl.monitor({ output = \"" + .name + "\", mode = \"preferred\", position = \"auto\", scale = " + (.scale|tostring) + ", mirror = \"" + .mirrorOf + "\", disabled = false })"
          else
            "hl.monitor({ output = \"" + .name + "\", mode = \"" + (.width|tostring) + "x" + (.height|tostring) + "@" + ((.refreshRate|round)|tostring) + "\", position = \"" + (.x|tostring) + "x" + (.y|tostring) + "\", scale = " + (.scale|tostring) + ", mirror = \"\", disabled = false })"
          end
        ' | while read -r cmd; do
            [ -n "$cmd" ] && hyprctl eval "$cmd" >/dev/null 2>&1
            sleep 0.1
        done
    else
        echo "$PREV_JSON" | jq -r '
          .[] |
          if .disabled then
            .name + ", disable"
          elif (.mirrorOf != "none" and (.mirrorOf | length > 0)) then
            .name + ", preferred, auto, " + (.scale|tostring) + ", mirror, " + .mirrorOf
          else
            .name + ", " + (.width|tostring) + "x" + (.height|tostring) + "@" + ((.refreshRate|round)|tostring) + ", " + (.x|tostring) + "x" + (.y|tostring) + ", " + (.scale|tostring)
          end
        ' | while read -r cmd; do
            [ -n "$cmd" ] && hyprctl keyword monitor "$cmd" >/dev/null 2>&1
            sleep 0.1
        done
    fi
    notify-send -u normal -i video-display "Display Switcher" "⚠️ Tampilan dikembalikan ke pengaturan sebelumnya."
}

run_watchdog() {
    local timeout="${1:-15}"
    echo $$ > "$WATCHDOG_PID_FILE"
    rm -f "$CONFIRM_FILE"
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        sleep 1
        if [ -f "$CONFIRM_FILE" ]; then
            rm -f "$CONFIRM_FILE" "$WATCHDOG_PID_FILE"
            exit 0
        fi
        if [ ! -f "$STATE_FILE" ]; then
            rm -f "$WATCHDOG_PID_FILE"
            exit 0
        fi
        elapsed=$((elapsed + 1))
    done
    rm -f "$WATCHDOG_PID_FILE"
    apply_revert
}

apply_mirror() {
    if [ -z "$EXT_MON" ] || [ "$EXT_MON" = "null" ]; then
        notify-send -u low -i video-display "Display Switcher" "Tidak ada proyektor / monitor eksternal terdeteksi."
        return
    fi
    acquire_lock
    save_previous_state

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
    start_failsafe
}

apply_extend() {
    local pos="${1:-left}"
    if [ -z "$EXT_MON" ] || [ "$EXT_MON" = "null" ]; then
        notify-send -u low -i video-display "Display Switcher" "Tidak ada proyektor / monitor eksternal terdeteksi."
        return
    fi
    acquire_lock
    save_previous_state

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
    start_failsafe
}

apply_laptop_only() {
    acquire_lock
    save_previous_state

    hyprctl dismissnotify -1 >/dev/null 2>&1
    if [ "$IS_LUA" = true ]; then
        if [ -n "$EXT_MON" ] && [ "$EXT_MON" != "null" ]; then
            hyprctl eval "hl.monitor({ output = '$EXT_MON', disabled = true })" >/dev/null 2>&1
            sleep 0.15
        fi
        hyprctl eval "hl.monitor({ output = '$LAPTOP_MON', mode = '$LAP_MODE', position = '0x0', scale = 1.0, disabled = false })" >/dev/null 2>&1
    else
        [ -n "$EXT_MON" ] && [ "$EXT_MON" != "null" ] && hyprctl keyword monitor "$EXT_MON, disable"
        sleep 0.15
        hyprctl keyword monitor "$LAPTOP_MON, $LAP_MODE, 0x0, 1"
    fi
    notify-send -u normal -i video-display "Display Mode" "💻 Laptop Only\nLayar $LAPTOP_MON aktif"
    start_failsafe
}

apply_projector_only() {
    if [ -z "$EXT_MON" ] || [ "$EXT_MON" = "null" ]; then
        notify-send -u low -i video-display "Display Switcher" "Tidak ada monitor eksternal terdeteksi."
        return
    fi
    acquire_lock
    save_previous_state

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
    start_failsafe
}

toggle_mirror_extend() {
    if [ -z "$EXT_MON" ] || [ "$EXT_MON" = "null" ]; then
        notify-send -u low -i video-display "Display Switcher" "Tidak ada proyektor / monitor eksternal terdeteksi."
        return
    fi
    IS_MIRROR=$(echo "$MONS_JSON" | jq -r --arg m "$EXT_MON" '.[] | select(.name == $m) | .mirrorOf')
    if [ "$IS_MIRROR" != "none" ] && [ -n "$IS_MIRROR" ] && [ "$IS_MIRROR" != "null" ]; then
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
    --confirm) confirm_changes ;;
    --revert) apply_revert ;;
    --watchdog) run_watchdog "$2" ;;
    --gui|--menu) toggle_gui ;;
    --toggle|"") toggle_mirror_extend ;;
    *) echo "Usage: $0 [--toggle | --gui | --mirror | --extend [left|right|top] | --laptop-only | --projector-only | --confirm | --revert | --no-failsafe]" ;;
esac
