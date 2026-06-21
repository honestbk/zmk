#!/bin/bash
## file: 00.build_crkbd_fw.sh
## brief: ZMK Corne keyboard firmware builder with minimal TUI
#
# AUTHOR: honest
#
# REFERENCES:
#   - ZMK Firmware:    https://zmk.dev/docs
#   - Build and flash: https://zmk.dev/docs/development/local-toolchain/build-flash
#
# Board:   nice_nano//zmk  (ZMK variant · nrf52840 · rev 2.0.0 default)
# Shields: corne_left, corne_right, settings_reset

# ── Color codes ───────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Spinner frames ────────────────────────────────────────────────────────────
_SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
_build_pid=   # PID of background west build; used by interrupt handler
_log_lines=0  # number of lines currently on screen (header + log); used for cleanup

# ── Build state (global) ──────────────────────────────────────────────────────
declare -A _result=()   # key → ok|fail
declare -A _elapsed=()  # key → seconds
declare -A _uf2=()      # key → output file path
_order_keys=()          # ordered list of built target keys
_order_names=()         # display names in same order
_menu_choice=           # set by tui_menu

# ── Interrupt handler ─────────────────────────────────────────────────────────
_on_interrupt() {
    if [[ -n "$_build_pid" ]]; then
        kill "$_build_pid" 2>/dev/null || true
        wait "$_build_pid" 2>/dev/null || true
        _build_pid=
    fi
    if [[ $_log_lines -gt 0 ]]; then
        printf "\033[%dA\033[J" "$_log_lines"
    fi
    printf "\n  ${YELLOW}Interrupted.${NC}\n\n"
    exit 1
}
trap '_on_interrupt' INT TERM

# ──────────────────────────────────────────────────────────────────────────────
# detect_config — find the ZMK config directory
# ──────────────────────────────────────────────────────────────────────────────
detect_config() {
    if [[ -d "/workspaces/zmk-config/config" ]]; then
        echo "/workspaces/zmk-config/config"
    elif [[ -d "zmk-config/config" ]]; then
        echo "$(pwd)/zmk-config/config"
    else
        echo ""
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# format_time — convert seconds to "Xm Ys" or "Ys"
# ──────────────────────────────────────────────────────────────────────────────
format_time() {
    local s="$1"
    local m=$((s / 60)) r=$((s % 60))
    [[ $m -gt 0 ]] && printf "%dm %ds" "$m" "$r" || printf "%ds" "$r"
}

# ──────────────────────────────────────────────────────────────────────────────
# _hbar — print n repetitions of '═'
# ──────────────────────────────────────────────────────────────────────────────
_hbar() {
    local n="$1" i
    for ((i = 0; i < n; i++)); do printf '═'; done
}

# ──────────────────────────────────────────────────────────────────────────────
# _live_log_display — show animated header + rolling 12-line log tail while
#                     a background build is running; updates in-place using
#                     ANSI cursor movement. Sets _log_lines for caller cleanup.
#   $1  display_name  e.g. "left half"
#   $2  log           path to the temp log file
#   $3  build_pid     PID of the background west build process
# ──────────────────────────────────────────────────────────────────────────────
_live_log_display() {
    local display_name="$1"
    local log="$2"
    local build_pid="$3"
    local tw; tw=$(tput cols 2>/dev/null || echo 80)
    local max=$(( tw - 4 ))
    local t0=$SECONDS
    local i_spin=0
    local prev=0  # tracks max log lines ever on screen; only increases

    printf "  \033[0;36m%s\033[0m  Building %s...\n" \
        "${_SPINNER[0]}" "$display_name"
    _log_lines=1

    while kill -0 "$build_pid" 2>/dev/null; do
        local e=$(( SECONDS - t0 ))
        local m=$((e / 60)) r=$((e % 60)) ts
        [[ $m -gt 0 ]] && ts="${m}m${r}s" || ts="${r}s"

        local content count=0
        content=$(tail -n 12 "$log" 2>/dev/null)
        [[ -n "$content" ]] && count=$(printf '%s\n' "$content" | wc -l)

        printf "\033[%dA" $(( prev + 1 ))

        printf "  \033[0;36m%s\033[0m  Building %s...  \033[2m(%s)\033[0m\033[K\n" \
            "${_SPINNER[$((i_spin % 10))]}" "$display_name" "$ts"

        local i=0
        if [[ -n "$content" ]]; then
            while IFS= read -r line; do
                printf "  \033[2m%-${max}.${max}s\033[0m\033[K\n" "$line"
                i=$(( i + 1 ))
            done <<< "$content"
        fi

        while (( i < prev )); do
            printf "\033[2K\n"
            i=$(( i + 1 ))
        done

        # prev only increases — tracks actual cursor distance from header
        (( count > prev )) && prev=$count
        _log_lines=$(( prev + 1 ))
        i_spin=$(( i_spin + 1 ))
        sleep 0.1
    done

    _log_lines=$(( prev + 1 ))
}

# ──────────────────────────────────────────────────────────────────────────────
# tui_header — banner + board/config info
# ──────────────────────────────────────────────────────────────────────────────
tui_header() {
    local title="ZMK Firmware Builder - Corne"
    local inner=50
    local tlen=${#title}
    local lpad=$(( (inner - tlen) / 2 ))
    local rpad=$(( inner - tlen - lpad ))
    local config
    config=$(detect_config)

    echo ""
    printf "  ${CYAN}╔"; _hbar "$inner"; printf "╗${NC}\n"
    printf "  ${CYAN}║${NC}%*s${BOLD}%s${NC}%*s${CYAN}║${NC}\n" \
        "$lpad" "" "$title" "$rpad" ""
    printf "  ${CYAN}╚"; _hbar "$inner"; printf "╝${NC}\n"
    echo ""
    printf "  ${DIM}Board${NC}   nice_nano//zmk  ${DIM}(rev 2.0.0)${NC}\n"
    if [[ -n "$config" ]]; then
        printf "  ${DIM}Config${NC}  %s\n" "$config"
    else
        printf "  ${YELLOW}Config${NC}  ${YELLOW}not found — using defaults${NC}\n"
    fi
    echo ""
}

# ──────────────────────────────────────────────────────────────────────────────
# tui_menu — arrow-key navigator; sets _menu_choice
#   Up/Down arrows move the cursor; Enter or q confirms / exits.
#   "Both sides" is listed first and pre-selected (most common build).
# ──────────────────────────────────────────────────────────────────────────────
tui_menu() {
    local -a items=("Both sides  (left + right)" "Left half" "Right half" "Settings reset" "Exit")
    local -a values=("both" "left" "right" "reset" "exit")
    local sel=0 total=5
    local lines=7   # header (1) + blank (1) + items (5)

    _menu_draw() {
        printf "  ${BOLD}Select build target:${NC}\n\n"
        local i
        for ((i = 0; i < total; i++)); do
            if (( i == sel )); then
                printf "  ${CYAN}▶${NC}  %s\n" "${items[$i]}"
            else
                printf "     %s\n" "${items[$i]}"
            fi
        done
    }

    _menu_draw

    local key seq
    while true; do
        IFS= read -rsn1 key
        if [[ "$key" == $'\033' ]]; then
            IFS= read -rsn2 -t 0.1 seq
            key="${key}${seq}"
        fi

        case "$key" in
            $'\033[A')
                (( sel > 0 )) && sel=$(( sel - 1 ))
                ;;
            $'\033[B')
                (( sel < total - 1 )) && sel=$(( sel + 1 ))
                ;;
            ''|$'\r'|$'\n')
                printf "\033[${lines}A\033[J"
                _menu_choice="${values[$sel]}"
                return
                ;;
            q|Q)
                printf "\033[${lines}A\033[J"
                _menu_choice="exit"
                return
                ;;
        esac

        printf "\033[${lines}A"
        _menu_draw
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# build_target — run west build in background with live log tail; show result
#   $1  display_name  e.g. "left half"
#   $2  shield        e.g. "corne_left"
#   $3  key           e.g. "corne_left"  (build dir and output filename)
#   $4  config_path   absolute path or empty
# returns 0 on success, 1 on failure
# ──────────────────────────────────────────────────────────────────────────────
build_target() {
    local display_name="$1"
    local shield="$2"
    local key="$3"
    local config_path="$4"
    local build_dir="build/${key}"
    local log
    log=$(mktemp)
    local t0=$SECONDS

    # Run build in background so we can display a live log tail in the foreground
    if [[ -n "$config_path" ]]; then
        west build -s app/ -p -d "$build_dir" -b "nice_nano//zmk" -- \
            -DSHIELD="$shield" \
            -DZMK_CONFIG="$config_path" > "$log" 2>&1 &
    else
        west build -s app/ -p -d "$build_dir" -b "nice_nano//zmk" -- \
            -DSHIELD="$shield" > "$log" 2>&1 &
    fi
    _build_pid=$!

    # Display animated header + rolling log tail until build finishes
    _live_log_display "$display_name" "$log" "$_build_pid"

    # Collect the build exit code
    wait "$_build_pid"
    local rc=$?
    _build_pid=

    # Clear the live display area (header + log lines) before printing result
    printf "\033[%dA\033[J" "$_log_lines"
    _log_lines=0

    local elapsed=$(( SECONDS - t0 ))
    _elapsed["$key"]=$elapsed
    _order_keys+=("$key")
    _order_names+=("$display_name")

    if [[ $rc -eq 0 && -f "${build_dir}/zephyr/zmk.uf2" ]]; then
        local uf2="build/${key}.uf2"
        cp "${build_dir}/zephyr/zmk.uf2" "$uf2"
        _result["$key"]="ok"
        _uf2["$key"]="$uf2"
        printf "  ${GREEN}✓${NC}  %-22s  ${DIM}%-8s →  %s${NC}\n" \
            "$display_name" "$(format_time "$elapsed")" "$uf2"
        rm -f "$log"
        return 0
    else
        _result["$key"]="fail"
        printf "  ${RED}✗${NC}  %-22s  ${DIM}%-8s${NC}  ${RED}FAILED${NC}\n" \
            "$display_name" "$(format_time "$elapsed")"
        echo ""
        printf "  ${DIM}─── last 30 lines of build output ───${NC}\n"
        tail -30 "$log" | while IFS= read -r line; do
            printf "  %s\n" "$line"
        done
        echo ""
        rm -f "$log"
        return 1
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# print_summary — totals + multi-target recap; returns 1 if any build failed
# ──────────────────────────────────────────────────────────────────────────────
print_summary() {
    local total=0 all_ok=true i

    for i in "${!_order_keys[@]}"; do
        local key="${_order_keys[$i]}"
        total=$(( total + _elapsed["$key"] ))
        [[ "${_result[$key]}" != "ok" ]] && all_ok=false
    done

    echo ""

    if [[ ${#_order_keys[@]} -gt 1 ]]; then
        printf "  ${DIM}──────────────────────────────────────────${NC}\n"
        printf "  ${BOLD}Build summary${NC}\n\n"
        for i in "${!_order_keys[@]}"; do
            local key="${_order_keys[$i]}"
            local name="${_order_names[$i]}"
            local t
            t=$(format_time "${_elapsed[$key]}")
            if [[ "${_result[$key]}" == "ok" ]]; then
                printf "  ${GREEN}✓${NC}  %-22s  ${DIM}%-8s →  %s${NC}\n" \
                    "$name" "$t" "${_uf2[$key]}"
            else
                printf "  ${RED}✗${NC}  %-22s  ${DIM}%-8s${NC}  ${RED}FAILED${NC}\n" \
                    "$name" "$t"
            fi
        done
        echo ""
        printf "  ${DIM}Total: %s${NC}\n" "$(format_time "$total")"
        printf "  ${DIM}──────────────────────────────────────────${NC}\n"
    else
        printf "  ${DIM}Total: %s${NC}\n" "$(format_time "$total")"
    fi

    echo ""
    $all_ok
}

# ──────────────────────────────────────────────────────────────────────────────
# show_help
# ──────────────────────────────────────────────────────────────────────────────
show_help() {
    local me
    me=$(basename "$0")
    cat << EOF

Usage: $me [TARGET]

Build ZMK firmware for the Corne keyboard (nice!nano v2).

Targets:
  left    Build left half only
  right   Build right half only
  reset   Build settings reset firmware only
  (none)  Launch interactive TUI menu

Options:
  -h, --help  Show this help and exit

Output files:
  build/corne_left.uf2
  build/corne_right.uf2
  build/settings_reset.uf2

Board:  nice_nano//zmk  (ZMK variant · nrf52840 · rev 2.0.0)
Note:   Run 'west update' once before first build to initialize the workspace.

EOF
}

# ──────────────────────────────────────────────────────────────────────────────
# main
# ──────────────────────────────────────────────────────────────────────────────
main() {
    local arg="${1:-}"
    local config
    config=$(detect_config)

    # Help
    case "$arg" in
        -h|--help) show_help; exit 0 ;;
    esac

    # Validate explicit target arg
    if [[ -n "$arg" ]]; then
        case "$arg" in
            left|right|reset) ;;
            *)
                printf "${RED}Error:${NC} unknown target '%s'\n" "$arg" >&2
                printf "Run '%s --help' for usage.\n" "$(basename "$0")" >&2
                exit 1
                ;;
        esac
    fi

    # Determine choice: from arg or interactive menu
    local choice="$arg"
    if [[ -z "$choice" ]]; then
        tui_header
        tui_menu
        choice="$_menu_choice"
        echo ""
    fi

    mkdir -p build

    # Dispatch
    local exit_code=0
    case "$choice" in
        exit)
            printf "  ${DIM}Cancelled.${NC}\n\n"
            exit 0
            ;;
        left)
            build_target "left half" "corne_left" "corne_left" "$config" \
                || exit_code=1
            ;;
        right)
            build_target "right half" "corne_right" "corne_right" "$config" \
                || exit_code=1
            ;;
        reset)
            build_target "settings reset" "settings_reset" "settings_reset" "$config" \
                || exit_code=1
            ;;
        both)
            if build_target "left half" "corne_left" "corne_left" "$config"; then
                echo ""
                build_target "right half" "corne_right" "corne_right" "$config" \
                    || exit_code=1
            else
                exit_code=1
                echo ""
                printf "  ${YELLOW}Right side skipped — left build failed.${NC}\n"
            fi
            ;;
    esac

    print_summary || exit_code=1
    exit $exit_code
}

main "$@"
