#!/usr/bin/env bash
set -e

# Test 1: Empty or disconnected monitor parsing does not produce empty geometry
TEST_JSON='[{"name":"eDP-1","width":1920,"height":1080,"refreshRate":144}]'
EXT_W=$(echo "$TEST_JSON" | jq -r --arg m "NONEXISTENT" '([.[] | select(.name == $m) | .width] | first) // 1920')
[ "$EXT_W" = "1920" ] || { echo "FAIL: Expected 1920, got '$EXT_W'"; exit 1; }

# Test 2: Mode parsing with non-standard strings falls back to preferred
NONSTD_JSON='[{"name":"EXT-1","availableModes":["custom_mode","auto"],"width":1920,"height":1080}]'
BEST_MODE=$(echo "$NONSTD_JSON" | jq -r --arg m "EXT-1" '
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
')
[ "$BEST_MODE" = "preferred" ] || { echo "FAIL: Expected preferred, got '$BEST_MODE'"; exit 1; }

# Test 3: Concurrency flock test
LOCK_FILE="/tmp/test_hypr_flock.lock"
exec 201>"$LOCK_FILE"
flock -n 201 || { echo "FAIL: Initial flock failed"; exit 1; }
(
    exec 202>"$LOCK_FILE"
    if flock -n 202; then
        echo "FAIL: Concurrent flock should have failed"
        exit 1
    fi
)
flock -u 201
rm -f "$LOCK_FILE"

echo "PASS: All edge-case tests passed successfully"
