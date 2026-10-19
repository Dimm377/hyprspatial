# Design System Specification for hypr-display-switcher

Design tokens, spatial geometry, and interaction rules for the Quickshell Wayland layer-shell overlays.

---

## 1. Palette & Color Tokens

Colors inherit dynamically from Serpantinum theme files (`qs_colors.json` / `qs_matugen_colors.json`) with hardcoded fallbacks:

| Token | Fallback Hex | Role & Usage |
| :--- | :--- | :--- |
| `base` | `#0f0f07` | Window background surface (98% opacity) |
| `crust` | `#14140c` | Spatial arrangement canvas recessed ground |
| `surface0` | `#202018` | Hardware screen faces, inactive keycap fill |
| `surface1` | `#2b2a22` | Machined borders, structural dividers, stand neck |
| `surface2` | `#36352c` | Stand baseplate, chassis edge highlights, hover states |
| `text` | `#e6e3d5` | Primary headings, active values (contrast > 14:1) |
| `subtext0` | `#c9c7b6` | Secondary labels, mode titles, keycaps (contrast > 10:1) |
| `subtext1` | `#939182` | Metadata labels, standby screen indicators (contrast > 5.4:1) |
| `mauve` | `#cacb77` | Primary focus indicator, active border, projection beam |
| `green` | `#c9c8a5` | Hardware online status LED, active mode badge |
| `peach` | `#f38ba8` | Revert countdown, error pill, disconnected warning |

---

## 2. Typography

| Role | Font Family | Size | Weight | Usage |
| :--- | :--- | :--- | :--- | :--- |
| **Heading** | `CaskaydiaCove Nerd Font`, Sans-serif | `13px` | DemiBold | Window header ("Display Arrangement") |
| **Mode Title** | `CaskaydiaCove Nerd Font`, Sans-serif | `12px` | DemiBold | Preset selector item titles |
| **Body Label** | `CaskaydiaCove Nerd Font`, Sans-serif | `10px` | Regular | Preset descriptions, context labels |
| **Telemetry / Data** | `CaskaydiaCove Nerd Font`, Monospace | `8.5px` | Regular | Resolution, refresh rate, canvas boundary |
| **Hotkeys** | `CaskaydiaCove Nerd Font`, Monospace | `9–10px` | Bold | Keycaps (`1-4`, `S / Tab`, `↵`, `Esc`) |

Rules:
- Text contrast must exceed **4.5:1** (WCAG AA).
- Minimum font size for any readable data is **8.5px** with `letterSpacing: 0.2`.
- No gradient text. Use font-weight and scale for emphasis.

---

## 3. Spatial Hardware Anatomy

All spatial elements represent real hardware proportions, anchored to a 1px desk baseline (`surface1`):

```
┌─────────────────────────────────┐
│     Spatial Viewport (Left)     │
│                                 │
│    ┌─────────┐     ┌────────┐   │
│    │ External│     │ Laptop │   │
│    │ Monitor │     │ Screen │   │
│    └────┬────┘     └───┬────┘   │
│       ──┴──          ──┴───     │
└─────────────────────────────────┘
```

1. **External Monitor**:
   - Screen panel: `158 × 90px` (radius: `5px`, border: `1px`)
   - Stand neck: `12 × 9px` (`surface1`)
   - Stand baseplate: `54 × 3.5px` (radius: `1.75px`, `surface2`)
2. **Laptop Display**:
   - Screen lid: `138 × 78px` (radius: `4px`, border: `1px`)
   - Keyboard chassis: `150 × 6px` (radius: `2px`, `surface1`)
   - Touchpad notch: `24 × 2px` (radius: `1px`, `surface2`)
3. **Projector (Mirror Mode)**:
   - Body: `122 × 50px` (radius: `6px`, `surface0`)
   - Optical lens aperture: `24 × 24px` circular bezel with inner lens
   - Projection light cone: HTML5 Canvas linear gradient (`mauve` 15% → 4% → 0%) with hairline center ray.

---

## 4. Motion & Tactile Feedback

- **Window Entrance**: Opacity `0.0 → 1.0`, Scale `0.98 → 1.0`, duration: `160ms`, `Easing.OutCubic`.
- **Window Dismissal**: Opacity `1.0 → 0.0`, Scale `1.0 → 0.98`, duration: `90ms`, `Easing.InCubic`.
- **Spatial Position Sliding**: `x` and `y` duration: `180ms`, `Easing.OutCubic`.
- **Selection Pill Slide**: `y` translation duration: `160ms`, `Easing.OutCubic`.
- **Tactile Button Press**: Scale compresses to `0.94–0.98` on click with `100ms` `Easing.OutCubic`.
