# ZMK Scripts

This directory contains utility scripts for ZMK firmware development.

## Directory Structure

- `bash/` - Bash utility scripts for building and managing firmware

## Bash Scripts

### 00.build_crkbd_fw.sh

Build script for ZMK firmware on Corne (CRKBD) keyboard using nice!nano controller (revision 2.0.0).

**Location:** `scripts/bash/00.build_crkbd_fw.sh`
**Usage:**

```bash
# Display help message
./scripts/bash/00.build_crkbd_fw.sh -h
./scripts/bash/00.build_crkbd_fw.sh --help

# Build both left and right sides (interactive)
./scripts/bash/00.build_crkbd_fw.sh

# Build left side only
./scripts/bash/00.build_crkbd_fw.sh left

# Build right side only
./scripts/bash/00.build_crkbd_fw.sh right

# Build settings reset firmware
./scripts/bash/00.build_crkbd_fw.sh reset
```

**Features:**

- Builds firmware for Corne keyboard split halves
- Supports building individual sides or both at once
- Includes settings reset firmware build option
- Help flag (`-h`/`--help`) displays usage information
- Automatically detects custom config directory
- Falls back to default configuration if no custom config found
- Displays build time for each build
- Color-coded success/error messages
- Automatically copies `.uf2` files to convenient locations

**Output:**

- Left side: `build/corne_left.uf2`
- Right side: `build/corne_right.uf2`
- Settings reset: `build/settings_reset.uf2`

**Prerequisites:**

- West workspace must be initialized (`west init -l app/` and `west update`)
- Optional: ZMK config directory at `/workspaces/zmk/zmk-config/config` or `./zmk-config/config`
- nice!nano board support (uses revision 2.0.0 by default)

**Configuration:**

The script builds with the following settings:

- Board: `nice_nano` (revision 2.0.0)
- Shield: `corne_left` / `corne_right` / `settings_reset`
- Config path: Auto-detected or uses default

## Getting Started

### Initial Setup

If you encounter errors like "west: unknown command 'build'", you need to initialize the west workspace:

```bash
# Navigate to the workspace root
cd /workspaces/zmk

# Initialize west workspace
west init -l app/

# Update all dependencies
west update
```

This only needs to be done once per workspace.

### Building Firmware

After the workspace is initialized, you can use the build scripts:

```bash
# Make the script executable
chmod +x scripts/bash/00.build_crkbd_fw.sh

# Run the build script
./scripts/bash/00.build_crkbd_fw.sh
```

## Notes

- Build artifacts are stored in the `build/` directory at the workspace root
- Each build uses pristine build (`-p` flag) to ensure clean builds
- The scripts use absolute paths to avoid path-related issues
