#!/bin/bash
# GingerOS - Phase 3 Orchestrator (Inside Chroot)

set -e
set -o pipefail

if [ -f /config/env.sh ]; then
    source /config/env.sh
else
    export LFS=${LFS}
    export LC_ALL=POSIX
    export LFS_TGT=$(uname -m)-lfs-linux-gnu
    export PATH=/tools/bin:/bin:/usr/bin
    export MAKEFLAGS=-j$(nproc)
    export CONFIG_SITE=$LFS/usr/share/config.site
fi

STATE_DIR="/var/lib/ginger"
mkdir -p "$STATE_DIR"

LOG_DIR="/var/log/ginger"
mkdir -p "$LOG_DIR"

echo "Inside Chroot: Starting Phase 3 (Final System Build)..."

SCRIPTS=(/lfs/phase3-system/*.sh)
TOTAL_PKGS=${#SCRIPTS[@]}
CURRENT_PKG_IDX=0

# Determine if a specific package was targeted via argument or env var
TARGET_PKG="${1:-${GINGER_ONLY_PKG:-${ONLY_PKG:-}}}"
# Parallel mode: builds multiple independent packages concurrently
# WARNING: experimental — may expose latent dependency issues
PARALLEL_PHASE3="${PARALLEL_PHASE3:-false}"
PARALLEL_WINDOW="${PARALLEL_WINDOW:-4}"

if [ -n "$TARGET_PKG" ]; then
    echo "Filtering Phase 3: Only executing package matching '$TARGET_PKG'"
fi

build_one_package() {
    local script="$1"
    local CURRENT_PKG_IDX="$2"
    local FILE_PKG_NAME="$3"
    local FULL_SCRIPT_NAME="$4"

    if bash "$script"; then
        touch "$STATE_DIR/${FULL_SCRIPT_NAME}.built"
        echo "Successfully built: ${FILE_PKG_NAME}"
        find /sources -mindepth 1 -maxdepth 1 -type d ! -name "build" -exec rm -rf {} + 2>/dev/null || true
        return 0
    else
        echo "Error: Failed to build ${FILE_PKG_NAME}"
        return 1
    fi
}

build_parallel_window() {
    local -n window_scripts="$1"
    local -n window_names="$2"
    local -n window_full="$3"
    local pids=()
    local idx=0

    for script in "${window_scripts[@]}"; do
        local fname="${window_names[$idx]}"
        local full="${window_full[$idx]}"
        echo "__GINGER_PKG_MARKER__: $fname"
        echo "__GINGER_PKG_COUNT__: (parallel) : $fname"
        echo "Building: $fname (Final System — parallel window)"
        build_one_package "$script" 0 "$fname" "$full" &
        pids+=($!)
        idx=$((idx + 1))
    done

    local failed=0
    for pid in "${pids[@]}"; do
        wait "$pid" || failed=1
    done

    return "$failed"
}

gather_unbuilt_scripts() {
    local -n out_scripts="$1"
    local -n out_file_names="$2"
    local -n out_full_names="$3"
    local first="$4"

    local idx=0
    local started=false
    for script in "${SCRIPTS[@]}"; do
        local FILE_PKG_NAME=$(basename "$script" .sh | cut -d'-' -f2-)
        local FULL_SCRIPT_NAME=$(basename "$script" .sh)

        if [ -n "$TARGET_PKG" ]; then
            local SCRIPT_PKG_NAME=$(grep -E "^PKG_NAME=" "$script" | cut -d'"' -f2 || echo "")
            if [[ "$FILE_PKG_NAME" =~ "$TARGET_PKG" ]] || [[ "$SCRIPT_PKG_NAME" =~ "$TARGET_PKG" ]] || [[ "$FULL_SCRIPT_NAME" =~ "$TARGET_PKG" ]]; then
                out_scripts+=("$script")
                out_file_names+=("$FILE_PKG_NAME")
                out_full_names+=("$FULL_SCRIPT_NAME")
                idx=$((idx + 1))
            fi
            continue
        fi

        if [ "$first" = "true" ] && [ -z "$started" ]; then
            if [ -f "$STATE_DIR/${FULL_SCRIPT_NAME}.built" ]; then
                continue
            fi
            started=true
        fi

        if [ -f "$STATE_DIR/${FULL_SCRIPT_NAME}.built" ]; then
            continue
        fi

        out_scripts+=("$script")
        out_file_names+=("$FILE_PKG_NAME")
        out_full_names+=("$FULL_SCRIPT_NAME")
        idx=$((idx + 1))
    done
}

if [ "$PARALLEL_PHASE3" = "true" ]; then
    echo "Experimental parallel mode enabled (window=$PARALLEL_WINDOW)"

    ALL_UNBUILT_SCRIPTS=()
    ALL_UNBUILT_NAMES=()
    ALL_UNBUILT_FULL=()

    gather_unbuilt_scripts ALL_UNBUILT_SCRIPTS ALL_UNBUILT_NAMES ALL_UNBUILT_FULL "false"

    if [ ${#ALL_UNBUILT_SCRIPTS[@]} -eq 0 ]; then
        echo "All Phase 3 packages are already built."
        exit 0
    fi

    echo "Remaining unbuilt packages: ${#ALL_UNBUILT_SCRIPTS[@]}"

    TOTAL_UNBUILT=${#ALL_UNBUILT_SCRIPTS[@]}
    WINDOW_START=0

    while [ "$WINDOW_START" -lt "$TOTAL_UNBUILT" ]; do
        WINDOW_END=$((WINDOW_START + PARALLEL_WINDOW))
        [ "$WINDOW_END" -gt "$TOTAL_UNBUILT" ] && WINDOW_END="$TOTAL_UNBUILT"

        WINDOW_SCRIPTS=("${ALL_UNBUILT_SCRIPTS[@]:WINDOW_START:WINDOW_END - WINDOW_START}")
        WINDOW_NAMES=("${ALL_UNBUILT_NAMES[@]:WINDOW_START:WINDOW_END - WINDOW_START}")
        WINDOW_FULL=("${ALL_UNBUILT_FULL[@]:WINDOW_START:WINDOW_END - WINDOW_START}")

        WINDOW_NUM=$((WINDOW_START / PARALLEL_WINDOW + 1))
        echo "--- Parallel window $WINDOW_NUM (packages $((WINDOW_START + 1))-$WINDOW_END of $TOTAL_UNBUILT) ---"

        if ! build_parallel_window WINDOW_SCRIPTS WINDOW_NAMES WINDOW_FULL; then
            echo "ERROR: Parallel build failed in window $WINDOW_NUM. Falling back to sequential for this window..."
            idx=0
            for script in "${WINDOW_SCRIPTS[@]}"; do
                local fname="${WINDOW_NAMES[$idx]}"
                local full="${WINDOW_FULL[$idx]}"
                if [ ! -f "$STATE_DIR/${full}.built" ]; then
                    echo "Retrying: $fname (sequential)"
                    if ! build_one_package "$script" 0 "$fname" "$full"; then
                        echo "FATAL: Package $fname failed to build even in sequential mode."
                        exit 1
                    fi
                fi
                idx=$((idx + 1))
            done
        fi

        WINDOW_START=$WINDOW_END
    done
else
    # Standard sequential mode
    for script in "${SCRIPTS[@]}"; do
        CURRENT_PKG_IDX=$((CURRENT_PKG_IDX + 1))
        SCRIPT_PKG_NAME=$(grep -E "^PKG_NAME=" "$script" | cut -d'"' -f2 || echo "")
        FILE_PKG_NAME=$(basename "$script" .sh | cut -d'-' -f2-)
        FULL_SCRIPT_NAME=$(basename "$script" .sh)

        if [ -n "$TARGET_PKG" ]; then
            if [[ ! "$FILE_PKG_NAME" =~ "$TARGET_PKG" ]] && [[ ! "$SCRIPT_PKG_NAME" =~ "$TARGET_PKG" ]] && [[ ! "$FULL_SCRIPT_NAME" =~ "$TARGET_PKG" ]]; then
                continue
            fi
            echo "Found matching target package: $FILE_PKG_NAME"
        else
            if [ -f "$STATE_DIR/${FULL_SCRIPT_NAME}.built" ]; then
                echo "__GINGER_PKG_COUNT__: $CURRENT_PKG_IDX/$TOTAL_PKGS : $FILE_PKG_NAME (Skipped)"
                continue
            fi
        fi

        echo "__GINGER_PKG_MARKER__: $FILE_PKG_NAME"
        echo "__GINGER_PKG_COUNT__: $CURRENT_PKG_IDX/$TOTAL_PKGS : $FILE_PKG_NAME"
        echo "Building: $FILE_PKG_NAME (Final System)"

        if [ ! -f "$STATE_DIR/${FULL_SCRIPT_NAME}.built" ]; then
            if ! build_one_package "$script" "$CURRENT_PKG_IDX" "$FILE_PKG_NAME" "$FULL_SCRIPT_NAME"; then
                echo "Error: Failed to build ${FILE_PKG_NAME}"
                exit 1
            fi
        fi
    done
fi

if [ -n "$TARGET_PKG" ]; then
    echo "Single package build attempt completed for: $TARGET_PKG"
fi
