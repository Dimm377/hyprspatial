#!/usr/bin/env bash
set -e

# Test snapshot saving and restore command generation
TEST_STATE="/tmp/test_hypr_state.json"
cat << 'JSON' > "$TEST_STATE"
[
  {"name":"eDP-1","width":1920,"height":1080,"refreshRate":144.0,"x":1920,"y":0,"scale":1,"disabled":false,"mirrorOf":"none"},
  {"name":"HDMI-A-1","width":1920,"height":1080,"refreshRate":240.0,"x":0,"y":0,"scale":1,"disabled":false,"mirrorOf":"none"}
]
JSON

# Parse Lua restore commands
LUA_CMDS=$(jq -r '
  .[] |
  if .disabled then
    "hl.monitor({ output = \"" + .name + "\", disabled = true })"
  elif (.mirrorOf != "none" and (.mirrorOf | length > 0)) then
    "hl.monitor({ output = \"" + .name + "\", mode = \"preferred\", position = \"auto\", scale = " + (.scale|tostring) + ", mirror = \"" + .mirrorOf + "\", disabled = false })"
  else
    "hl.monitor({ output = \"" + .name + "\", mode = \"" + (.width|tostring) + "x" + (.height|tostring) + "@" + ((.refreshRate|round)|tostring) + "\", position = \"" + (.x|tostring) + "x" + (.y|tostring) + "\", scale = " + (.scale|tostring) + ", mirror = \"\", disabled = false })"
  end
' "$TEST_STATE")

echo "$LUA_CMDS" | grep -q 'output = "HDMI-A-1"' || { echo "FAIL: missing HDMI-A-1 Lua command"; exit 1; }
echo "$LUA_CMDS" | grep -q 'output = "eDP-1"' || { echo "FAIL: missing eDP-1 Lua command"; exit 1; }

# Parse Legacy Keyword restore commands
KW_CMDS=$(jq -r '
  .[] |
  if .disabled then
    .name + ", disable"
  elif (.mirrorOf != "none" and (.mirrorOf | length > 0)) then
    .name + ", preferred, auto, " + (.scale|tostring) + ", mirror, " + .mirrorOf
  else
    .name + ", " + (.width|tostring) + "x" + (.height|tostring) + "@" + ((.refreshRate|round)|tostring) + ", " + (.x|tostring) + "x" + (.y|tostring) + ", " + (.scale|tostring)
  end
' "$TEST_STATE")

echo "$KW_CMDS" | grep -q 'HDMI-A-1, 1920x1080@240, 0x0, 1' || { echo "FAIL: missing HDMI-A-1 keyword command"; exit 1; }
echo "$KW_CMDS" | grep -q 'eDP-1, 1920x1080@144, 1920x0, 1' || { echo "FAIL: missing eDP-1 keyword command"; exit 1; }

rm -f "$TEST_STATE"
echo "PASS: Snapshot restoration logic verified"
