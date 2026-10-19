#!/usr/bin/env bash
set -e

STATE_FILE="/tmp/hypr_display_switcher_prev_state.json"
CONFIRM_FILE="/tmp/hypr_display_confirmed"
WATCHDOG_PID_FILE="/tmp/hypr_display_watchdog.pid"

# Clean any existing artifacts
rm -f "$STATE_FILE" "$CONFIRM_FILE" "$WATCHDOG_PID_FILE"

echo '[{"name":"TEST-1","width":1920,"height":1080,"refreshRate":60}]' > "$STATE_FILE"

# Test 1: Watchdog cancelled by confirmation
/home/dimm/hypr-display-switcher/scripts/toggle-presentation.sh --watchdog 5 >/dev/null 2>&1 &
WD_PID=$!
sleep 0.5

[ -f "$WATCHDOG_PID_FILE" ] || { echo "FAIL: Watchdog PID file not created"; kill "$WD_PID" 2>/dev/null; exit 1; }

# Trigger confirmation
/home/dimm/hypr-display-switcher/scripts/toggle-presentation.sh --confirm

sleep 0.5
if kill -0 "$WD_PID" 2>/dev/null; then
    echo "FAIL: Watchdog should have exited after confirmation"
    kill "$WD_PID" 2>/dev/null
    exit 1
fi

[ ! -f "$STATE_FILE" ] || { echo "FAIL: State file should be cleaned after confirmation"; exit 1; }
echo "PASS: Watchdog successfully cancelled by user confirmation"

# Test 2: Help output verification
USAGE_OUT=$(/home/dimm/hypr-display-switcher/scripts/toggle-presentation.sh --help)
echo "$USAGE_OUT" | grep -q "Usage:" || { echo "FAIL: Missing usage output"; exit 1; }
echo "PASS: Usage output verified"

rm -f "$STATE_FILE" "$CONFIRM_FILE" "$WATCHDOG_PID_FILE"
echo "All failsafe integration tests passed successfully!"
