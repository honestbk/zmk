# ZMK Scripts

This directory contains utility scripts for ZMK firmware development.

## Directory Structure

- `bash/` - Bash utility scripts for building and managing firmware

---

## `00.build_crkbd_fw.sh` — Corne keyboard build script

Wraps the `west build` commands for the Corne (CRKBD) keyboard with nice!nano controller. Handles
pristine builds, config path detection, timing output, and copying the final `.uf2` files to a
convenient location.

**Use this script** when doing day-to-day firmware iteration. Use raw `west build` commands directly
only when you need to pass custom CMake flags not covered by the script.

**Location:** `scripts/bash/00.build_crkbd_fw.sh`

### First-time setup

```bash
chmod +x scripts/bash/00.build_crkbd_fw.sh
```

### Usage

```bash
./scripts/bash/00.build_crkbd_fw.sh [left|right|reset]
```

| Argument        | Behaviour                                                 |
| --------------- | --------------------------------------------------------- |
| _(none)_        | Show TUI menu — choose left / right / reset / both / exit |
| `left`          | Build left half only (no menu)                            |
| `right`         | Build right half only (no menu)                           |
| `reset`         | Build settings reset firmware (no menu)                   |
| `-h` / `--help` | Show help and exit                                        |

### Output

| Target         | File                       |
| -------------- | -------------------------- |
| Left half      | `build/corne_left.uf2`     |
| Right half     | `build/corne_right.uf2`    |
| Settings reset | `build/settings_reset.uf2` |

### What the script does

- Detects the ZMK config path automatically (`/workspaces/zmk-config/config` → `./zmk-config/config`
  → default)
- Runs `west build -s app/ -p ...` with `nice_nano//zmk` as the board target — the ZMK-specific
  variant required for RGB underglow and ext-power overlays to be applied (replaces the old
  `nice_nano` / `nice_nano_v2` board names)
- Copies the resulting `zmk.uf2` to the `build/` root with a descriptive name
- Reports per-build time and total time with color-coded pass/fail output

### Features

- **Interactive TUI menu** when run with no arguments — single keypress selection, no Enter needed
- **Live spinner** with elapsed time counter during each build
- **Build output suppressed** on success (clean display); last 30 lines shown automatically on
  failure
- Pristine builds (`-p`) every time to avoid stale CMake cache issues
- Color-coded result lines (✓ / ✗) and multi-target summary with total time
- Graceful exit on first failure when building both sides
- Ctrl+C safe — spinner is cleaned up and terminal is left in a usable state
- Backward compatible — `./script.sh left|right|reset` skips the menu and runs directly (scriptable)

### Prerequisites

- West workspace initialized — run `west update` once before first build (see
  [main README](../README.md#step-3--initialize-the-west-workspace))
- ZMK config repo mounted at `/workspaces/zmk-config` (configured in
  `.devcontainer/devcontainer.json`)

---

## Notes

- Build artifacts live in `build/` at the workspace root
- Each build is pristine (`-p`) — incremental builds are not used to keep config changes reliable
