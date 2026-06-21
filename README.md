# Zephyr™ Mechanical Keyboard (ZMK) Firmware

[![Discord](https://img.shields.io/discord/719497620560543766)](https://zmk.dev/community/discord/invite)
[![Build](https://github.com/zmkfirmware/zmk/workflows/Build/badge.svg)](https://github.com/zmkfirmware/zmk/actions)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg)](CODE_OF_CONDUCT.md)

[ZMK Firmware](https://zmk.dev/) is an open source ([MIT](LICENSE)) keyboard firmware built on the
[Zephyr™ Project](https://www.zephyrproject.org/) Real Time Operating System (RTOS). ZMK's goal is
to provide a modern, wireless, and powerful firmware free of licensing issues.

Check out the website to learn more: https://zmk.dev/.

You can also come join our [ZMK Discord Server](https://zmk.dev/community/discord/invite).

To review features, check out the [feature overview](https://zmk.dev/docs/). ZMK is under active
development, and new features are listed with the
[enhancement label](https://github.com/zmkfirmware/zmk/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)
in GitHub. Please feel free to add 👍 to the issue description of any requests to upvote the
feature.

---

## Quick Start (Corne / CRKBD with nice!nano v2)

This fork is set up for local development inside a Docker dev container. Follow the steps below from
a fresh clone.

### Step 1 — Prerequisites

- **Docker Desktop** installed and running
- **WSL2 Ubuntu integration** enabled: Docker Desktop → Settings → Resources → WSL Integration →
  toggle **Ubuntu** on → Apply & Restart
- **VS Code** with the
  [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
  extension installed

### Step 2 — Open in Dev Container

1. Open this folder in VS Code
2. When prompted "Reopen in Container", click it — or open the Command Palette (`Ctrl+Shift+P`) and
   run **Dev Containers: Reopen in Container**
3. Wait for the container image to build (first time only; subsequent opens are fast)

### Step 3 — Initialize the West Workspace

Run this once inside the container terminal. It populates the `zmk-zephyr` Docker volume with Zephyr
source and all HAL modules. The volume persists across container restarts so you only need to do
this once.

```bash
west update
```

Verify it worked:

```bash
west build --help
```

You should see the build command help with no errors.

### Step 4 — Build Firmware

#### Option A: custom build script (recommended)

```bash
# Make executable (once)
chmod +x scripts/bash/00.build_crkbd_fw.sh

# Build both halves interactively
./scripts/bash/00.build_crkbd_fw.sh

# Or build a specific target
./scripts/bash/00.build_crkbd_fw.sh left    # left half only
./scripts/bash/00.build_crkbd_fw.sh right   # right half only
./scripts/bash/00.build_crkbd_fw.sh reset   # settings reset firmware
```

Output files land in `build/`:

| Target         | Output file                |
| -------------- | -------------------------- |
| Left half      | `build/corne_left.uf2`     |
| Right half     | `build/corne_right.uf2`    |
| Settings reset | `build/settings_reset.uf2` |

See [`scripts/README.md`](scripts/README.md) for full script documentation.

#### Option B: manual west commands

```bash
# Left half
west build -s app/ -p -d build/corne_left -b nice_nano//zmk -- \
  -DSHIELD=corne_left \
  -DZMK_CONFIG=/workspaces/zmk-config/config/

# Right half
west build -s app/ -p -d build/corne_right -b nice_nano//zmk -- \
  -DSHIELD=corne_right \
  -DZMK_CONFIG=/workspaces/zmk-config/config/

# Settings reset
west build -s app/ -p -d build/settings_reset -b nice_nano//zmk -- \
  -DSHIELD=settings_reset
```

**Flag reference:**

| Flag                  | Meaning                                                                                          |
| --------------------- | ------------------------------------------------------------------------------------------------ |
| `-s app/`             | Source directory — where ZMK's `CMakeLists.txt` lives                                            |
| `-p`                  | Pristine build — clean the build directory first                                                 |
| `-d build/corne_left` | Build output directory (keep left/right separate)                                                |
| `-b nice_nano//zmk`   | Board target — ZMK variant of nice!nano (nrf52840); required for RGB/ext-power overlays to apply |
| `--`                  | Separator; everything after goes to CMake                                                        |
| `-DSHIELD=corne_left` | Which keyboard shield/PCB to build for                                                           |
| `-DZMK_CONFIG=...`    | Path to your personal keymap and config files                                                    |

---

## Troubleshooting

**`west: unknown command "build"`** The Zephyr source hasn't been fetched yet. Run `west update` and
try again.

**Docker error: `ubuntu.sock: no such file or directory`** Docker Desktop can't reach your WSL2
Ubuntu distro. Go to Docker Desktop → Settings → Resources → WSL Integration and make sure
**Ubuntu** is toggled on, then click Apply & Restart Docker Desktop.
