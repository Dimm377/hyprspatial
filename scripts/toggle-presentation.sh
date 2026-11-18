#!/usr/bin/env bash
# Hyprland display switcher and presentation toggle

# Per-user 0700 runtime dir: a shared /tmp would let other users plant a snapshot that revert replays
RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STATE_FILE="$RUN_DIR/hypr_display_switcher_prev_state.json"
CONFIRM_FILE="$RUN_DIR/hypr_display_confirmed"
WATCHDOG_PID_FILE="$RUN_DIR/hypr_display_watchdog.pid"
LOCK_FILE="$RUN_DIR/hypr_display_switcher.lock"

acquire_lock() {
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        # Non-zero so the overlay shows this instead of closing as if the switch worked
        echo "Another display change is still running. Try again in a moment." >&2
        exit 1
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
if [ "$(hyprctl status -j 2>/dev/null | jq -r '.configProvider // empty')" = "lua" ]; then
    IS_LUA=true
elif hyprctl status 2>/dev/null | grep -q "configProvider: lua"; then
    IS_LUA=true
elif hyprctl keyword dummy test 2>&1 | grep -qE "non-legacy|unknown request"; then
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
            # Skip 24/30Hz modes (e.g. 4K@30 advertised by 1080p projectors) when a 50Hz+ mode exists
            (map(select(.r >= 50)) as $smooth | if ($smooth | length) > 0 then $smooth else . end) |
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

get_scale() {
    echo "$MONS_JSON" | jq -r --arg m "$1" '([.[] | select(.name == $m) | .scale | select(. != null and . > 0)][0]) // 1'
}

# Layout positions are logical pixels: size of the mode we apply, divided by the monitor's scale
logical_size() {
    echo "$MONS_JSON" | jq -r --arg m "$1" --arg mode "$2" '
        ([.[] | select(.name == $m)][0] // {}) as $mon |
        ($mode | capture("^(?<w>[0-9]+)x(?<h>[0-9]+)") // {w: ($mon.width // 0), h: ($mon.height // 0)}) as $px |
        (if ($mon.scale // 0) > 0 then $mon.scale else 1 end) as $s |
        def px(v; d): (v | tonumber) as $n | if $n > 0 then $n else d end;
        "\(px($px.w; 1920) / $s | floor) \(px($px.h; 1080) / $s | floor)"'
}

EXT_SCALE=$(get_scale "$EXT_MON")
LAP_SCALE=$(get_scale "$LAPTOP_MON")
read -r EXT_W EXT_H <<< "$(logical_size "$EXT_MON" "$EXT_MODE")"
read -r LAP_W LAP_H <<< "$(logical_size "$LAPTOP_MON" "$LAP_MODE")"

# Optional ICC profile handling (failsafe)
ICC_PATH=""
if [ -n "$EXT_MON" ] && [ "$EXT_MON" != "null" ]; then
    # Model first: a port name (HDMI-A-1) also matches whatever projector is plugged into that port
    EXT_MODEL=$(echo "$MONS_JSON" | jq -r --arg m "$EXT_MON" '[.[] | select(.name == $m) | .model // empty][0] // empty')
    for candidate in \
        ${EXT_MODEL:+"$HOME/.config/hypr/profiles/${EXT_MODEL}_sRGB.icm"} \
        "$HOME/.config/hypr/profiles/${EXT_MON}_sRGB.icm" \
        "$HOME/.local/share/icc/${EXT_MON}.icm" \
        "$HOME/.local/share/icc/${EXT_MON}.icc"; do
        if [ -f "$candidate" ]; then
            ICC_PATH="$candidate"
            break
        fi
    done
fi

# Monitor rules as JSON objects, consumed by apply_layout
rule_off() { jq -nc --arg n "$1" '{name: $n, disabled: true}'; }
rule_mirror() { jq -nc --arg n "$1" --arg src "$2" --argjson s "$3" '{name: $n, mirror: $src, scale: $s}'; }
rule_at() { # name mode x y scale [icc]
    jq -nc --arg n "$1" --arg mode "$2" --argjson x "$3" --argjson y "$4" --argjson s "$5" --arg icc "${6:-}" \
        '{name: $n, mode: $mode, x: $x, y: $y, scale: $s} + (if $icc != "" then {icc: $icc} else {} end)'
}

# Apply rules in an order that never overlaps two monitors in between (Hyprland warns
# "monitor layout is set up incorrectly" on every transient overlap):
#   1. disables  2. mirrors (they leave the layout)  3. park monitors whose current spot
#   blocks another monitor's target far to the right (swaps)  4. final positions
apply_layout() {
    printf '%s\n' "$@" | jq -s -r --argjson cur "$MONS_JSON" --arg lua "$IS_LUA" '
        def size($n; $mode; $s): ($cur | map(select(.name == $n))[0] // {}) as $c
            | ($mode | capture("^(?<w>[0-9]+)x(?<h>[0-9]+)") // {w: ($c.width // 1920), h: ($c.height // 1080)})
            | {w: ((.w | tonumber) / $s), h: ((.h | tonumber) / $s)};
        def hits($a; $b): $a.name != $b.name
            and $a.x < $b.x + $b.w and $b.x < $a.x + $a.w and $a.y < $b.y + $b.h and $b.y < $a.y + $a.h;
        def lua: if .disabled then "hl.monitor({ output = \(.name | @json), disabled = true })"
            elif .mirror then "hl.monitor({ output = \(.name | @json), mode = \"preferred\", position = \"auto\", scale = \(.scale), mirror = \(.mirror | @json), disabled = false })"
            else "hl.monitor({ output = \(.name | @json), mode = \(.mode | @json), position = \"\(.x)x\(.y)\", scale = \(.scale), mirror = \"\", disabled = false\(if .icc then ", icc = \(.icc | @json)" else "" end) })"
            end;
        def keyword: if .disabled then "\(.name), disable"
            elif .mirror then "\(.name), preferred, auto, \(.scale), mirror, \(.mirror)"
            else "\(.name), \(.mode), \(.x)x\(.y), \(.scale)"
            end;
        map(select(.name != "")) as $rules
        | [$rules[] | select(.disabled)] as $off
        | [$rules[] | select((.disabled | not) and .mirror)] as $mir
        | [$rules[] | select((.disabled | not) and (.mirror | not))] as $placed
        | ([$off[], $mir[]] | map(.name)) as $leaving
        | [$placed[] | {name, x, y} + size(.name; .mode; .scale)] as $targets
        | [$cur[] | select((.disabled | not) and ((.mirrorOf // "none") | IN("none", ""))
                           and (.name | IN($leaving[]) | not))
                  | {name, x, y} + size(.name; ""; (if (.scale // 0) > 0 then .scale else 1 end))] as $now
        | [$now[] | . as $n | select(any($targets[]; hits($n; .))) | .name] as $blocking
        | ($off + $mir + [$placed[] | select(.name | IN($blocking[])) | .x += 100000] + $placed)[]
        | if $lua == "true" then lua else keyword end
    ' | while read -r cmd; do
        if [ "$IS_LUA" = true ]; then
            hyprctl eval "$cmd" >/dev/null 2>&1
        else
            hyprctl keyword monitor "$cmd" >/dev/null 2>&1
        fi
        sleep 0.15
    done
}

save_previous_state() {
    # Keep the original snapshot only while a transition still awaits confirmation (watchdog alive)
    if [ ! -f "$STATE_FILE" ] || ! kill -0 "$(cat "$WATCHDOG_PID_FILE" 2>/dev/null)" 2>/dev/null; then
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

    # Background children close fd 200 (200>&-): an inherited fd keeps the flock held and blocks --revert.
    # Watchdog fires 2s after the dialog's 15s countdown, so it only acts if the dialog never reverted.
    nohup "$0" --watchdog 17 200>&- >/dev/null 2>&1 &
    echo $! > "$WATCHDOG_PID_FILE"

    # Launch Quickshell confirmation dialog
    pkill -f "ConfirmDialog\.qml" 2>/dev/null || true
    if [ -f "$HOME/.config/hypr/display-switcher/ConfirmDialog.qml" ]; then
        quickshell -p "$HOME/.config/hypr/display-switcher/ConfirmDialog.qml" 200>&- >/dev/null 2>&1 &
    elif [ -f "$(dirname "$0")/../quickshell/ConfirmDialog.qml" ]; then
        quickshell -p "$(dirname "$0")/../quickshell/ConfirmDialog.qml" 200>&- >/dev/null 2>&1 &
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
    notify-send -u low -i video-display "Display Switcher" "Display layout kept."
}

apply_revert() {
    acquire_lock
    if [ ! -f "$STATE_FILE" ]; then
        notify-send -u low -i video-display "Display Switcher" "Nothing to revert."
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
    local rules
    mapfile -t rules < <(echo "$PREV_JSON" | jq -c --arg ext "$EXT_MON" --arg icc "$ICC_PATH" '.[] |
        if .disabled then {name, disabled: true}
        elif ((.mirrorOf // "none") | IN("none", "") | not) then {name, mirror: .mirrorOf, scale}
        else {name, mode: "\(.width)x\(.height)@\(.refreshRate | round)", x, y, scale}
             + (if .name == $ext and $icc != "" then {icc: $icc} else {} end)
        end')
    apply_layout "${rules[@]}"
    notify-send -u normal -i video-display "Display Switcher" "Previous display layout restored."
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
        notify-send -u low -i video-display "Display Switcher" "No external display connected."
        return
    fi
    acquire_lock
    save_previous_state

    hyprctl dismissnotify -1 >/dev/null 2>&1
    apply_layout "$(rule_mirror "$EXT_MON" "$LAPTOP_MON" "$EXT_SCALE")" \
                 "$(rule_at "$LAPTOP_MON" "$LAP_MODE" 0 0 "$LAP_SCALE")"
    notify-send -u normal -i video-display "Mirror Display" "Laptop screen duplicated on the external display"
    start_failsafe
}

apply_extend() {
    local pos="${1:-left}"
    if [ -z "$EXT_MON" ] || [ "$EXT_MON" = "null" ]; then
        notify-send -u low -i video-display "Display Switcher" "No external display connected."
        return
    fi
    acquire_lock
    save_previous_state

    hyprctl dismissnotify -1 >/dev/null 2>&1
    case "$pos" in
        right)
            apply_layout "$(rule_at "$LAPTOP_MON" "$LAP_MODE" 0 0 "$LAP_SCALE")" \
                         "$(rule_at "$EXT_MON" "$EXT_MODE" "$LAP_W" 0 "$EXT_SCALE" "$ICC_PATH")"
            notify-send -u normal -i video-display "Extend Desktop" "External on the right of the laptop"
            ;;
        top)
            apply_layout "$(rule_at "$EXT_MON" "$EXT_MODE" 0 0 "$EXT_SCALE" "$ICC_PATH")" \
                         "$(rule_at "$LAPTOP_MON" "$LAP_MODE" 0 "$EXT_H" "$LAP_SCALE")"
            notify-send -u normal -i video-display "Extend Desktop" "External above the laptop"
            ;;
        left|*)
            apply_layout "$(rule_at "$EXT_MON" "$EXT_MODE" 0 0 "$EXT_SCALE" "$ICC_PATH")" \
                         "$(rule_at "$LAPTOP_MON" "$LAP_MODE" "$EXT_W" 0 "$LAP_SCALE")"
            notify-send -u normal -i video-display "Extend Desktop" "External on the left of the laptop"
            ;;
    esac
    start_failsafe
}

apply_laptop_only() {
    acquire_lock
    save_previous_state

    hyprctl dismissnotify -1 >/dev/null 2>&1
    apply_layout "$(rule_off "$EXT_MON")" "$(rule_at "$LAPTOP_MON" "$LAP_MODE" 0 0 "$LAP_SCALE")"
    notify-send -u normal -i video-display "Laptop Screen Only" "External display turned off"
    start_failsafe
}

apply_projector_only() {
    if [ -z "$EXT_MON" ] || [ "$EXT_MON" = "null" ]; then
        notify-send -u low -i video-display "Display Switcher" "No external display connected."
        return
    fi
    acquire_lock
    save_previous_state

    hyprctl dismissnotify -1 >/dev/null 2>&1
    apply_layout "$(rule_off "$LAPTOP_MON")" "$(rule_at "$EXT_MON" "$EXT_MODE" 0 0 "$EXT_SCALE" "$ICC_PATH")"
    notify-send -u normal -i video-display "External Display Only" "Laptop screen turned off"
    start_failsafe
}

toggle_mirror_extend() {
    if [ -z "$EXT_MON" ] || [ "$EXT_MON" = "null" ]; then
        notify-send -u low -i video-display "Display Switcher" "No external display connected."
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
