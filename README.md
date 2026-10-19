# hypr-display-switcher

Display manager and presentation switcher overlay for Hyprland, built with Quickshell (QML) and Bash.

<p align="center">
  <img src="assets/screenshot.png" alt="hypr-display-switcher overlay" width="820">
</p>

## Features

- **Dynamic display detection**: Reads connected outputs, native resolutions, and refresh rates directly from `hyprctl monitors -j`. Works without hardcoded monitor names or ports.
- **Position swap (`S` / `Tab`)**: In Extend mode, press `S` or `Tab` to cycle the external display between Left, Right, and Top.
- **Spatial canvas**: Visual preview showing relative screen positions and aspect ratios before applying changes.
- **Mirror mode**: Duplicates the laptop display to external displays or projectors with a single keypress.
- **15-second failsafe timer**: Saves display state before applying changes. If an external display loses signal or you do not confirm within 15 seconds, the script automatically reverts to the previous configuration.
- **Concurrency locking**: Uses `flock` to prevent race conditions from rapid key presses.
- **Optional ICC profiles**: Applies color profiles from `~/.config/hypr/profiles/` or `~/.local/share/icc/` when available.

## Requirements

- `hyprland`
- `quickshell` (or `quickshell-git`)
- `jq`
- `libnotify` (`notify-send`)
- Any Nerd Font (e.g., `ttf-cascadia-cove-nerd`)

```bash
# Arch Linux
sudo pacman -S hyprland jq libnotify ttf-cascadia-cove-nerd
yay -S quickshell-git

# Fedora
sudo dnf install hyprland jq libnotify
```

## Installation

```bash
git clone https://github.com/<your-username>/hypr-display-switcher.git
cd hypr-display-switcher
chmod +x install.sh
./install.sh
```

The installer symlinks the QML files to `~/.config/hypr/display-switcher/` and the script to `~/.config/hypr/scripts/toggle-presentation.sh`.

## Keybindings

### Standard config (`~/.config/hypr/hyprland.conf`)

```ini
# Open switcher overlay
bind = $mainMod SHIFT, P, exec, ~/.config/hypr/scripts/toggle-presentation.sh --gui

# Toggle mirror / extend
bind = $mainMod, P, exec, ~/.config/hypr/scripts/toggle-presentation.sh
bind = , XF86Display, exec, ~/.config/hypr/scripts/toggle-presentation.sh
```

### Lua config (`~/.config/hypr/config/keybinds.lua`)

```lua
-- Open switcher overlay
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/toggle-presentation.sh --gui"))

-- Toggle mirror / extend
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/toggle-presentation.sh"))
hl.bind("XF86Display", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/toggle-presentation.sh"), { locked = true })
```

## Shortcuts

When the switcher is open:

| Key | Action |
| :---: | :--- |
| `1` | Laptop screen only |
| `2` | Mirror display |
| `3` | Extend desktop |
| `4` | External monitor only |
| `S` / `Tab` | Cycle position: Left, Right, Top |
| `↑` / `↓` | Navigate presets |
| `Enter` | Apply selected preset |
| `Esc` | Close without changes |

## CLI Usage

```bash
# Toggle between Mirror and Extend
~/.config/hypr/scripts/toggle-presentation.sh

# Open GUI overlay
~/.config/hypr/scripts/toggle-presentation.sh --gui

# Direct modes (starts 15-second failsafe timer)
~/.config/hypr/scripts/toggle-presentation.sh --extend left
~/.config/hypr/scripts/toggle-presentation.sh --extend right
~/.config/hypr/scripts/toggle-presentation.sh --extend top
~/.config/hypr/scripts/toggle-presentation.sh --mirror
~/.config/hypr/scripts/toggle-presentation.sh --laptop-only
~/.config/hypr/scripts/toggle-presentation.sh --projector-only

# Apply without failsafe timer
~/.config/hypr/scripts/toggle-presentation.sh --extend left --no-failsafe

# Failsafe commands
~/.config/hypr/scripts/toggle-presentation.sh --confirm
~/.config/hypr/scripts/toggle-presentation.sh --revert
```

## Color Calibration (Optional)

Place your `.icm` or `.icc` profile in either directory:

- `~/.config/hypr/profiles/<MONITOR_NAME>_sRGB.icm`
- `~/.local/share/icc/<MONITOR_NAME>.icm`

The script automatically appends `, icc = '...'` to the Hyprland rule when the file exists.

## Uninstallation

```bash
cd hypr-display-switcher
./uninstall.sh
```

## License

Distributed under the [MIT License](LICENSE).
