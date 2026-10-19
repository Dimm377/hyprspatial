# hyprspatial

Spatial display switcher and multi-monitor management overlay for Hyprland.

<p align="center">
  <img src="assets/screenshot.png" alt="hyprspatial overlay preview" width="820">
</p>

## Overview

hyprspatial provides hardware-accurate multi-monitor switching for Hyprland compositors. It pairs an elevated Quickshell UI overlay with a POSIX/Bash IPC engine to preview display arrangements, cycle monitor positions, and apply configurations with an automated 15-second failsafe reversion watchdog.

## Technical Architecture

The project separates visual presentation from hardware configuration:

- **Frontend (`quickshell/`)**: Built on Quickshell and QtQuick Wayland layershell (`WlrLayer.Overlay`). Renders real-time display topology, physical monitor and laptop chassis mockups, projector light cones, and preset controls. Runs statelessly and exits upon mode execution.
- **Engine (`scripts/toggle-presentation.sh`)**: Queries `hyprctl monitors all -j` and parse output states using `jq`. Detects active outputs, maximum supported refresh rates, and primary display roles. Dynamically determines whether the host runs standard Hyprland keyword syntax or Lua dispatchers (`hl.monitor`), applying configurations atomically.
- **Failsafe System**: Prior to executing any layout change, the engine saves the current display configuration to `/tmp/hypr_display_switcher_prev_state.json` and spawns a background watchdog process. If the user does not confirm the new configuration within 15 seconds (or if video signal is lost), the watchdog reverts monitors to the saved snapshot.

## Operating Modes

1. **Laptop Screen Only (`1`)**: Powers off external outputs and sets the internal laptop panel to its native mode at `0x0`.
2. **Mirror Display (`2`)**: Duplicates the laptop display stream to connected external displays or projectors.
3. **Extend Desktop (`3`)**: Arranges displays side-by-side or stacked. Pressing `S` or `Tab` cycles the external display position between Left (`0x0`), Right (`+1920x0`), and Top (`0x0` stacked).
4. **External Monitor Only (`4`)**: Disables the internal laptop screen and assigns primary desktop workspaces to the external display.

## Keybindings & Navigation

### Overlay Navigation

When the studio overlay is open:

| Key | Action |
| :--- | :--- |
| `1` | Select Laptop Screen Only mode |
| `2` | Select Mirror Display mode |
| `3` | Select Extend Desktop mode |
| `4` | Select External Monitor Only mode |
| `S` / `Tab` | Cycle Extend arrangement (Left, Right, Top) |
| `↑` / `↓` | Navigate preset list |
| `Enter` | Apply selected configuration |
| `Esc` | Dismiss overlay without making changes |

### Confirmation Dialog Shortcuts

When the 15-second failsafe prompt is active:

| Key | Action |
| :--- | :--- |
| `Enter` / `K` | Confirm and keep current display configuration |
| `Esc` / `R` | Revert immediately to previous display state |

## Requirements

The following packages must be installed on your system:

- `hyprland` (Wayland compositor)
- `quickshell` (Wayland QtQuick shell framework)
- `jq` (JSON processor for monitor inspection)
- `libnotify` (`notify-send` for state feedback)

Optional:
- Nerd Font (e.g. `ttf-cascadia-cove-nerd`) for terminal keycap glyphs.

### Package Installation

Arch Linux:
```bash
sudo pacman -S hyprland jq libnotify ttf-cascadia-cove-nerd
yay -S quickshell-git
```

Fedora:
```bash
sudo dnf install hyprland jq libnotify
```

Ubuntu / Debian:
```bash
sudo apt install hyprland jq libnotify-bin
```

## Installation

Clone the repository and run the automated installer:

```bash
git clone https://github.com/Dimm377/hyprspatial.git
cd hyprspatial
chmod +x install.sh
./install.sh
```

The installer verifies system dependencies and creates the following symlinks:
- `~/.config/hypr/display-switcher/DisplaySwitcher.qml`
- `~/.config/hypr/display-switcher/ConfirmDialog.qml`
- `~/.config/hypr/display-switcher/components`
- `~/.config/hypr/scripts/toggle-presentation.sh`

## Hyprland Configuration

Add shortcut bindings to your Hyprland configuration file.

### Standard Configuration (`~/.config/hypr/hyprland.conf`)

```ini
# Open visual studio overlay
bind = $mainMod SHIFT, P, exec, ~/.config/hypr/scripts/toggle-presentation.sh --gui

# Quick toggle mirror and extend
bind = $mainMod, P, exec, ~/.config/hypr/scripts/toggle-presentation.sh
bind = , XF86Display, exec, ~/.config/hypr/scripts/toggle-presentation.sh
```

### Lua Configuration (`~/.config/hypr/config/keybinds.lua`)

```lua
-- Open visual studio overlay
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/toggle-presentation.sh --gui"))

-- Quick toggle mirror and extend
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/toggle-presentation.sh"))
hl.bind("XF86Display", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/toggle-presentation.sh"), { locked = true })
```

## CLI Usage

The core script can be controlled directly from terminal or custom scripts:

```bash
# Toggle between Mirror and Extend modes
~/.config/hypr/scripts/toggle-presentation.sh

# Open visual switcher overlay
~/.config/hypr/scripts/toggle-presentation.sh --gui

# Apply specific display modes (with 15-second failsafe watchdog)
~/.config/hypr/scripts/toggle-presentation.sh --extend left
~/.config/hypr/scripts/toggle-presentation.sh --extend right
~/.config/hypr/scripts/toggle-presentation.sh --extend top
~/.config/hypr/scripts/toggle-presentation.sh --mirror
~/.config/hypr/scripts/toggle-presentation.sh --laptop-only
~/.config/hypr/scripts/toggle-presentation.sh --projector-only

# Apply configuration without watchdog timer
~/.config/hypr/scripts/toggle-presentation.sh --extend left --no-failsafe

# Failsafe control commands
~/.config/hypr/scripts/toggle-presentation.sh --confirm
~/.config/hypr/scripts/toggle-presentation.sh --revert
```

## Color Profile Calibration (ICC / ICM)

The script checks for ICC color profiles matching connected monitors in:
- `~/.config/hypr/profiles/<MONITOR_NAME>_sRGB.icm`
- `~/.local/share/icc/<MONITOR_NAME>.icm` (or `.icc`)

When present, the engine automatically passes `icc = '<path>'` to the monitor rule.

## Verification & Testing

Run the included automated test suite to verify failsafe execution, concurrency locking, and state snapshot logic:

```bash
for test in tests/test_*.sh; do
    bash "$test"
done
```

Lint QML components:

```bash
qmllint quickshell/*.qml quickshell/components/*.qml
```

## Uninstallation

To remove symlinks and restore any previous configuration files:

```bash
cd hyprspatial
./uninstall.sh
```

## License

MIT License. See [LICENSE](LICENSE) for details.
