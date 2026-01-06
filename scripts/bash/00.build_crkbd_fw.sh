## file: build_crkbd_fw.sh
## brief: Script to build ZMK firmware for Corne keyboard (left and right sides)

# ------------------------------------------------------------------------------------------------ #
# INTRODUCTION: Build ZMK firmware for Corne keyboard (left, right, or settings reset).
#               Usage: ./build_crkbd_fw.sh [left|right|reset]
#
# AUTHOR(S): honest
#
# REFERENCES DOCUMENTS :
# - ZMK Firmware: https://zmk.dev/docs
# - ZMK Local toolchain setup: https://zmk.dev/docs/development/local-toolchain/setup
# - ZMK Building and flashing: https://zmk.dev/docs/development/local-toolchain/build-flash
#
# NOTE:
# - N/A
#
# ------------------------------------------------------------------------------------------------ #

#!/bin/bash

# Return value constants
readonly E_OK=0
readonly E_NOT_OK=1

# Function to display help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [SIDE]

Build ZMK firmware for Corne keyboard with nice!nano controller.

Arguments:
  left          Build left side firmware only
  right         Build right side firmware only
  reset         Build settings reset firmware only
  (none)        Interactive mode - prompts to build both sides

Options:
  -h, --help    Display this help message and exit

Examples:
  $(basename "$0")              # Interactive mode - build both sides
  $(basename "$0") left         # Build left side only
  $(basename "$0") right        # Build right side only
  $(basename "$0") reset        # Build settings reset firmware

Output:
  Firmware files are saved to the build/ directory:
    - build/corne_left.uf2
    - build/corne_right.uf2
    - build/settings_reset.uf2

Board: nice_nano (default revision 2.0.0)
Shields: corne_left, corne_right, settings_reset

Note: Make sure west workspace is initialized before running this script.
      Run 'west init -l app/' and 'west update' if needed.
EOF
    exit $E_OK
}

# Check for help flag
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

SIDE=$1   # left or right

# Detect ZMK config path
ZMK_CONFIG_PATH=""
if [ -d "/workspaces/zmk/zmk-config/config" ]; then
    ZMK_CONFIG_PATH="/workspaces/zmk/zmk-config/config"
    echo "Using custom config from: ${ZMK_CONFIG_PATH}"
elif [ -d "zmk-config/config" ]; then
    ZMK_CONFIG_PATH="$(pwd)/zmk-config/config"
    echo "Using custom config from: ${ZMK_CONFIG_PATH}"
else
    echo "No custom config found - using default configuration"
fi

# Function to format time in seconds to human readable format
format_time() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))

    if [ $minutes -eq 0 ]; then
        echo "${remaining_seconds}s"
    else
        echo "${minutes}m ${remaining_seconds}s"
    fi
}

# Function to build a specific side
build_side() {
    local side=$1
    local start_time=$(date +%s)

    echo "Building ${side} side..."

    if [ -n "${ZMK_CONFIG_PATH}" ]; then
        west build -s app/ -p -d build/corne_${side} -b nice_nano -- \
            -DSHIELD=corne_${side} \
            -DZMK_CONFIG="${ZMK_CONFIG_PATH}"
    else
        west build -s app/ -p -d build/corne_${side} -b nice_nano -- \
            -DSHIELD=corne_${side}
    fi

    local build_result=$?
    local end_time=$(date +%s)
    local build_time=$((end_time - start_time))
    local formatted_time=$(format_time $build_time)

    if [ $build_result -eq $E_OK ]; then
        # Check if the firmware file actually exists before copying
        if [ -f "build/corne_${side}/zephyr/zmk.uf2" ]; then
            cp build/corne_${side}/zephyr/zmk.uf2 build/corne_${side}.uf2
            echo -e "\e[32m✓ ${side} side build completed successfully in ${formatted_time}!\e[0m"
            echo "Firmware saved as: build/corne_${side}.uf2"
            return $E_OK
        else
            echo -e "\e[31m✗ ${side} side build failed - firmware file not found after ${formatted_time}!\e[0m"
            return $E_NOT_OK
        fi
    else
        echo -e "\e[31m✗ ${side} side build failed after ${formatted_time}!\e[0m"
        return $E_NOT_OK
    fi
}

# Add this function to your script
build_settings_reset() {
    local start_time=$(date +%s)

    echo "Building settings reset firmware..."

    if [ -n "${ZMK_CONFIG_PATH}" ]; then
        west build -s app/ -p -d build/settings_reset -b nice_nano -- \
            -DSHIELD=settings_reset \
            -DZMK_CONFIG="${ZMK_CONFIG_PATH}"
    else
        west build -s app/ -p -d build/settings_reset -b nice_nano -- \
            -DSHIELD=settings_reset
    fi

    local build_result=$?
    local end_time=$(date +%s)
    local build_time=$((end_time - start_time))
    local formatted_time=$(format_time $build_time)

    if [ $build_result -eq $E_OK ]; then
        if [ -f "build/settings_reset/zephyr/zmk.uf2" ]; then
            cp build/settings_reset/zephyr/zmk.uf2 build/settings_reset.uf2
            echo -e "\e[32m✓ Settings reset firmware built successfully in ${formatted_time}!\e[0m"
            echo "Firmware saved as: build/settings_reset.uf2"
            return $E_OK
        else
            echo -e "\e[31m✗ Settings reset build failed - firmware file not found after ${formatted_time}!\e[0m"
            return $E_NOT_OK
        fi
    else
        echo -e "\e[31m✗ Settings reset build failed after ${formatted_time}!\e[0m"
        return $E_NOT_OK
    fi
}

# If argument provided, validate it
if [ -n "$SIDE" ]; then
    if [ "$SIDE" != "left" ] && [ "$SIDE" != "right" ] && [ "$SIDE" != "reset" ]; then
        echo "Error: Invalid argument '$SIDE'. Only 'left', 'right', or 'reset' are allowed."
        echo "Usage: $0 {left|right|reset}"
        exit $E_NOT_OK
    fi

    if [ "$SIDE" == "reset" ]; then
        total_start=$(date +%s)
        build_settings_reset
        build_result=$?
        total_end=$(date +%s)
        total_time=$((total_end - total_start))
        echo
        echo -e "\e[36mTotal build time: $(format_time $total_time)\e[0m"
        exit $build_result
    fi

    # Build specified side and track total time
    total_start=$(date +%s)
    build_side "$SIDE"
    if [ $? -eq $E_OK ]; then
        total_end=$(date +%s)
        total_time=$((total_end - total_start))
        echo
        echo -e "\e[36mTotal build time: $(format_time $total_time)\e[0m"
        exit $E_OK
    else
        exit $E_NOT_OK
    fi
else
    # No argument provided, prompt user
    echo "No side specified."
    echo "Would you like to build both left and right sides? (y/N): "
    read -r response

    if [[ -z "$response" || "$response" =~ ^[Yy]$ ]]; then
        echo "Building both sides..."
        echo

        # Create build directory if it doesn't exist
        mkdir -p build

        # Track total time for both builds
        total_start=$(date +%s)

        # Build left side first
        build_side "left"
        if [ $? -ne $E_OK ]; then
            echo "Left side build failed. Stopping."
            exit $E_NOT_OK
        fi

        echo

        # Build right side
        build_side "right"
        if [ $? -ne $E_OK ]; then
            echo "Right side build failed."
            exit $E_NOT_OK
        fi

        total_end=$(date +%s)
        total_time=$((total_end - total_start))

        echo
        echo "============================================================"
        echo -e "\e[32m🎉 Both sides built successfully!\e[0m"
        echo "Firmware files:"
        echo "  - Left:  build/left.uf2"
        echo "  - Right: build/right.uf2"
        echo "------------------------------------------------------------"
        echo -e "\e[36mBuild time summary:\e[0m"
        echo "  - Total time: $(format_time $total_time)"
        echo "============================================================"
        exit $E_OK
    else
        echo "============================================================"
        echo -e "\e[31mBuild cancelled.\e[0m"
        echo "Usage: $0 {left|right} or run without arguments to build both sides"
        echo "============================================================"
        exit $E_NOT_OK
    fi
fi
