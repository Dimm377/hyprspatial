# Agent Protocols for hypr-display-switcher

Unified engineering, design, and documentation standards for `hypr-display-switcher`. Every agent working in this repository must follow these four core pillars.

---

## 1. Engineering Protocol (Superpowers)

### Systematic Debugging
- Investigate the root cause before proposing any fix. Never apply symptom patches.
- Trace the data flow across component boundaries: `hyprctl` JSON → bash parsing (`jq`) → Quickshell QML properties → system state.
- If a bug is reported, write a minimal failing test script in `tests/` to reproduce it before modifying code.

### Test-Driven Development & Hardening
- Every new feature or bug fix must have a corresponding test script in `tests/`.
- Test edge cases explicitly: disconnected displays, non-standard refresh rates, empty `jq` queries, rapid hotkey execution.
- Maintain concurrency safety: all monitor reconfiguration commands in `toggle-presentation.sh` must hold the `flock` lock (`/tmp/hypr_display_switcher.lock`).

### Verification Before Completion
- Never claim a task is complete without fresh terminal evidence.
- Required verification gates before any commit:
  ```bash
  # 1. Shell syntax check
  bash -n scripts/toggle-presentation.sh install.sh uninstall.sh

  # 2. QML syntax validation
  qmllint quickshell/ConfirmDialog.qml quickshell/DisplaySwitcher.qml

  # 3. Test suite execution
  bash tests/test_script_edge_cases.sh
  bash tests/test_snapshot_revert.sh
  bash tests/test_failsafe_cycle.sh
  ```
- **Daemon Safety Rule**: Never run `killall quickshell`. The user's desktop bar (Serpantinum) runs on Quickshell under PID 1833. Target only specific window PIDs or launch test processes with custom config flags.

---

## 2. Interface Craft & Accessibility (Impeccable)

### Surface Mode: Operate
This is a desktop utility. Prioritize scanability, keyboard ergonomics, information density, and instant response. Avoid decorative distraction.

### Theming & Dynamic Tokens
- Consume colors dynamically from `themeColors` (derived from Serpantinum's `~/.local/state/serpantinum/qs_colors.json` or `qs_matugen_colors.json`).
- Always provide solid fallback values:
  - `base`: `#0f0f07` (ground surface)
  - `surface0`: `#202018`, `surface1`: `#2b2a22`, `surface2`: `#36352c` (elevated layers)
  - `text`: `#e6e3d5`, `subtext0`: `#c9c7b6`, `subtext1`: `#939182` (type hierarchy)
  - `mauve`: `#cacb77` (focused selection accent)
  - `peach`: `#f38ba8` (revert / warning / error)
  - `green`: `#c9c8a5` (connected LED / active state)

### Elevation & Nested Radius Rules
- **Single-Source Elevation**: Use either a 1px machined hairline border (`border.width: 1; border.color: surface1`) or a soft directional shadow. Avoid heavy borders combined with blurry drop shadows.
- **Nested Radius Formula**: Inner child radius must follow $R_{\text{inner}} = R_{\text{outer}} - \text{padding}$.
  - Main Window Card: `12px`
  - Preset Row: `6px`
  - Keycap: `4px`
  - Chip / Tag: `4px`

### Accessibility & Contrast Standards
- Maintain WCAG AA contrast ratio (≥ 4.5:1) for all text against its immediate background.
- Minimum font size for technical metadata: `8.5px` with positive letter spacing (`letterSpacing: 0.2`). Never use sub-8px text.
- Comprehensive keyboard accessibility: every selectable mode, position swap, confirmation, and dismissal must work 100% via keyboard hotkeys (`1-4`, `S`, `Tab`, `Enter`, `Esc`, `↑/↓`).

---

## 3. Physical Anchoring & Motion (Taste Skills)

### Physical Metaphors Over Abstract Boxes
- Do not draw generic placeholder cards. Render physical desktop representations:
  - External display: monitor panel, stand neck, and desk baseplate.
  - Laptop: display lid, keyboard deck chassis, and trackpad notch.
  - Presentation mode: optical projector body, lens aperture, and focused light cone canvas.
- Dynamic layout sliding: when switching positions (`S` / `Tab`), displays physically slide past each other on the spatial canvas with actual aspect ratio proportions.

### Anti-AI Tells
- No 3-column generic card grids.
- No floating pill kickers or badge labels above titles.
- No generic purple/cyan blur glow in backgrounds.
- No raw unicode emojis used as interface icons. Use precision geometric indicators, SVG vectors, or monospaced glyphs (`⇄`, `↑↓`, `↵`).

### Calibrated Micro-Motion
- Standard transition duration: **140–180ms** with `Easing.OutCubic`.
- Tactile feedback: buttons and interactive chips must compress slightly on press:
  ```qml
  scale: mouseArea.pressed ? 0.94 : (mouseArea.containsMouse ? 1.03 : 1.0)
  Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
  ```

---

## 4. Writing & Documentation (No-AI-Slop)

### Direct, Human Communication
- State what the software does, how to install it, and how to configure it.
- Never use strawman comparisons ("Most tools do X, but our tool does Y").
- Never use fake-insight setups, colon reveals, or mic-drop summary endings.

### Banned Word List
Do not use the following words in README, code comments, commit messages, or UI copy:
- *robust, leverage, delve, foster, empower, seamless, intricate, multifaceted, cutting-edge, elevate, supercharge, harness, tapestry, realm, beacon*.

### Active Voice & Concrete Facts
- "Reads monitor topology from `hyprctl monitors -j`" beats "Provides dynamic hardware detection capabilities."
- Commit messages must follow Conventional Commits (`feat:`, `fix:`, `style:`, `docs:`) with concrete summaries.
