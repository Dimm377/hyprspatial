# 15-Second Failsafe Auto-Revert Timer & Script Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a 15-second failsafe auto-revert system that restores the previous display configuration automatically if the user encounters a black screen or does not confirm changes, alongside comprehensive script hardening against edge cases and race conditions.

**Architecture:** A lightweight snapshot-and-restore engine in `toggle-presentation.sh` saves the active display geometry to `/tmp/hypr_display_switcher_prev_state.json` before applying new settings. A detached watchdog background process manages a 15-second countdown. A snappy Quickshell confirmation dialog (`ConfirmDialog.qml`) allows immediate confirmation (`Enter`) or manual revert (`Esc`). If 15 seconds elapse without confirmation, the watchdog automatically executes `toggle-presentation.sh --revert`.

**Tech Stack:** Bash, Hyprland (`hyprctl`), `jq`, Quickshell (Qt 6 QML / LayerShell), Linux Wayland.

**Spec:** Requirement from user prompt: Add a 15-Second Failsafe Auto-Revert Timer (confirmation dialog + auto-revert on blank screen/timeout) and fix edge cases (unplugging during animation, non-standard modes, empty jq parsing, race conditions).

## Global Constraints

- Never use `killall quickshell` (PID 1833 runs Serpantinum bar daemon).
- 100% dynamic hardware detection; no hardcoded monitor names or ports.
- Snappy UI animations (160–180ms `Easing.OutCubic`) matching dark Catppuccin-inspired palette.
- Backward compatibility: support both Hyprland Lua parser (`hl.monitor`) and legacy keyword parser (`hyprctl keyword monitor`).

## Review Focus

1. Empty `jq` output when HDMI cable is disconnected must not produce invalid geometry like `x0` or crash Hyprland.
2. Concurrent rapid executions of `toggle-presentation.sh` must be locked via file lock (`flock`) to prevent conflicting commands.
3. Watchdog process must cleanly terminate upon user confirmation (`Enter`) and avoid leaving orphaned background loops.
4. Auto-revert must restore exact resolutions, refresh rates, positions, and mirror states from the pre-switch snapshot.
5. If Quickshell fails to launch or is killed, the detached bash watchdog must still revert after 15 seconds as a headless failsafe.

---

### Task 1: Script Hardening & Edge-Case Fixes (Audit Findings)

**Files:**
- Modify: `scripts/toggle-presentation.sh`
- Test: `tests/test_script_edge_cases.sh`

**Interfaces:**
- Consumes: `hyprctl monitors all -j`
- Produces: Safe fallback geometry (`EXT_W`, `EXT_H`, `LAP_W`, `LAP_H`), concurrency mutex lock `/tmp/hypr_display_switcher.lock`

- [ ] **Step 1: Write the failing test for empty jq and geometry fallbacks**

```bash
cat << 'EOF' > /home/dimm/hypr-display-switcher/tests/test_script_edge_cases.sh
#!/usr/bin/env bash
set -e
# Test that empty or disconnected monitor parsing does not produce empty geometry
TEST_JSON='[{"name":"eDP-1","width":1920,"height":1080,"refreshRate":144}]'
EXT_W=$(echo "$TEST_JSON" | jq -r --arg m "NONEXISTENT" '([.[] | select(.name == $m) | .width] | first) // 1920')
[ "$EXT_W" = "1920" ] || { echo "FAIL: Expected 1920, got '$EXT_W'"; exit 1; }
echo "PASS: Fallback geometry verified"
EOF
chmod +x /home/dimm/hypr-display-switcher/tests/test_script_edge_cases.sh
```

- [ ] **Step 2: Run test to verify behavior**

Run: `bash /home/dimm/hypr-display-switcher/tests/test_script_edge_cases.sh`
Expected: PASS

- [ ] **Step 3: Implement script hardening in `scripts/toggle-presentation.sh`**

- Add concurrency file locking via `flock -n 200` to prevent rapid race conditions.
- Replace `.[] | select(.name == $m) | .width // 1920` with `([.[] | select(.name == $m) | .width] | first) // 1920` and bash parameter defaults `${EXT_W:-1920}`.
- Refactor `[ -z "$EXT_MODE" ] || ... && ...` into standard `if ... fi` blocks.
- Add error check ensuring `LAPTOP_MON` is never empty before sending commands.

- [ ] **Step 4: Run bash syntax verification**

Run: `bash -n /home/dimm/hypr-display-switcher/scripts/toggle-presentation.sh`
Expected: exit 0

- [ ] **Step 5: Commit Task 1**

```bash
git add scripts/toggle-presentation.sh tests/test_script_edge_cases.sh
git commit -m "fix(script): harden monitor detection against empty jq output and race conditions"
```

---

### Task 2: State Snapshot & Revert Engine in `toggle-presentation.sh`

**Files:**
- Modify: `scripts/toggle-presentation.sh`
- Test: `tests/test_snapshot_revert.sh`

**Interfaces:**
- Consumes: `/tmp/hypr_display_switcher_prev_state.json`, `/tmp/hypr_display_confirmed`, `/tmp/hypr_display_watchdog.pid`
- Produces: CLI flags `--revert`, `--confirm`, `--watchdog <seconds>`, `--no-failsafe`

- [ ] **Step 1: Write test for state snapshot and command reconstruction**

```bash
cat << 'EOF' > /home/dimm/hypr-display-switcher/tests/test_snapshot_revert.sh
#!/usr/bin/env bash
set -e
# Verify state snapshot file creation and restore command generator
STATE_FILE="/tmp/test_hypr_state.json"
cat << 'JSON' > "$STATE_FILE"
[
  {"name":"eDP-1","width":1920,"height":1080,"refreshRate":144.0,"x":1920,"y":0,"scale":1,"disabled":false,"mirrorOf":"none"},
  {"name":"HDMI-A-1","width":1920,"height":1080,"refreshRate":240.0,"x":0,"y":0,"scale":1,"disabled":false,"mirrorOf":"none"}
]
JSON

# Parse restore commands
CMD=$(jq -r '.[] | "hl.monitor({ output = \"" + .name + "\", mode = \"" + (.width|tostring) + "x" + (.height|tostring) + "@" + ((.refreshRate|round)|tostring) + "\", position = \"" + (.x|tostring) + "x" + (.y|tostring) + "\", scale = " + (.scale|tostring) + ", disabled = " + (.disabled|tostring) + " })"' "$STATE_FILE")
echo "$CMD" | grep -q "output = \"HDMI-A-1\"" || { echo "FAIL: missing HDMI-A-1"; exit 1; }
echo "$CMD" | grep -q "output = \"eDP-1\"" || { echo "FAIL: missing eDP-1"; exit 1; }
rm -f "$STATE_FILE"
echo "PASS: Snapshot restoration logic verified"
EOF
chmod +x /home/dimm/hypr-display-switcher/tests/test_snapshot_revert.sh
```

- [ ] **Step 2: Run test to verify snapshot restoration logic**

Run: `bash /home/dimm/hypr-display-switcher/tests/test_snapshot_revert.sh`
Expected: PASS

- [ ] **Step 3: Implement snapshot, `--revert`, `--confirm`, and `--watchdog` in `scripts/toggle-presentation.sh`**

- `save_previous_state()`: writes `$MONS_JSON` to `/tmp/hypr_display_switcher_prev_state.json`.
- `apply_revert()`: restores monitors from JSON snapshot, notifies user, closes confirm modal.
- `confirm_changes()`: creates `/tmp/hypr_display_confirmed`, kills watchdog PID, removes state snapshot, notifies user.
- `run_watchdog(seconds)`: ticks down seconds; if confirmation flag appears, exits cleanly; if timer hits 0, triggers `apply_revert`.
- Trigger watchdog in background after applying mode when `--no-failsafe` is omitted.

- [ ] **Step 4: Verify syntax and dry-run revert/confirm**

Run: `bash /home/dimm/hypr-display-switcher/scripts/toggle-presentation.sh --confirm`
Expected: Clean confirmation, exit 0

- [ ] **Step 5: Commit Task 2**

```bash
git add scripts/toggle-presentation.sh tests/test_snapshot_revert.sh
git commit -m "feat(failsafe): add snapshot saving, auto-revert engine, and watchdog countdown"
```

---

### Task 3: Modern Snappy Failsafe Confirmation Overlay in Quickshell

**Files:**
- Create: `quickshell/ConfirmDialog.qml`
- Modify: `scripts/toggle-presentation.sh` (launch confirm dialog)
- Modify: `install.sh` & `uninstall.sh` (symlink and cleanup)

**Interfaces:**
- Consumes: `/tmp/hypr_display_watchdog.pid`, `/tmp/hypr_display_switcher_prev_state.json`
- Produces: Visual 15s countdown timer with progress bar, Enter/Esc hotkeys, Keep/Revert actions

- [ ] **Step 1: Create `quickshell/ConfirmDialog.qml`**

- Exclusive Wayland Overlay layer window.
- Centered compact dark card (360x160px) with 160ms scale/opacity entrance animation.
- Title: "Keep Display Settings?"
- Description: "Reverting automatically in <seconds>s if unconfirmed."
- Animated smooth progress bar shrinking from 100% to 0% over 15 seconds.
- Action Buttons:
  - Keep Changes (`Enter` / Click): executes `toggle-presentation.sh --confirm` and quits.
  - Revert Now (`Esc` / Click): executes `toggle-presentation.sh --revert` and quits.
- Timer ticks down every 1 second; automatically calls revert and closes at 0.

- [ ] **Step 2: Verify QML syntax via dry-run**

Run: `quickshell -p /home/dimm/hypr-display-switcher/quickshell/ConfirmDialog.qml --check 2>&1 || true`
Expected: No fatal QML syntax errors.

- [ ] **Step 3: Integrate ConfirmDialog launch into `scripts/toggle-presentation.sh`**

- In `toggle-presentation.sh`, after applying mode, launch `quickshell -p $HOME/.config/hypr/display-switcher/ConfirmDialog.qml >/dev/null 2>&1 &`.
- Update `install.sh` and `uninstall.sh` to symlink `ConfirmDialog.qml` into `~/.config/hypr/display-switcher/ConfirmDialog.qml`.

- [ ] **Step 4: Test installer idempotency**

Run: `bash /home/dimm/hypr-display-switcher/install.sh`
Expected: All symlinks successfully updated without errors.

- [ ] **Step 5: Commit Task 3**

```bash
git add quickshell/ConfirmDialog.qml scripts/toggle-presentation.sh install.sh uninstall.sh
git commit -m "feat(ui): add modern quickshell failsafe confirmation dialog with 15s countdown"
```

---

### Task 4: Documentation and End-to-End Verification

**Files:**
- Modify: `README.md`
- Test: All automated test scripts in `tests/`

- [ ] **Step 1: Update README.md**

- Add "15-Second Failsafe Auto-Revert" to the feature list.
- Document CLI arguments (`--confirm`, `--revert`, `--no-failsafe`).
- Add confirmation modal shortcuts (`Enter` to keep, `Esc` to revert).

- [ ] **Step 2: Run complete test suite and verification commands**

Run:
```bash
bash -n /home/dimm/hypr-display-switcher/scripts/toggle-presentation.sh
bash -n /home/dimm/hypr-display-switcher/install.sh
bash -n /home/dimm/hypr-display-switcher/uninstall.sh
bash /home/dimm/hypr-display-switcher/tests/test_script_edge_cases.sh
bash /home/dimm/hypr-display-switcher/tests/test_snapshot_revert.sh
```
Expected: All exit 0.

- [ ] **Step 3: Verify git status and commit**

```bash
git add README.md
git commit -m "docs: document 15-second failsafe auto-revert timer and CLI options"
```
