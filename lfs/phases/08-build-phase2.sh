#!/bin/bash
# GingerOS - Phase 2 Orchestrator
# Runs inside the LFS user environment

set -e
set -o pipefail

PHASE2_SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PHASE2_TOOLS_DIR="$PHASE2_SCRIPT_DIR/../phase2-tools"
source "${PHASE2_SCRIPT_DIR}/../lib/common.sh"
STATE_DIR="${LFS}/var/lib/ginger"
mkdir -p "$STATE_DIR"

SCRIPTS=("$PHASE2_TOOLS_DIR"/*.sh)
TOTAL_PKGS=${#SCRIPTS[@]}
CURRENT_PKG_IDX=0

# Determine if a specific package was targeted via argument or env var
TARGET_PKG="${1:-${GINGER_ONLY_PKG:-${ONLY_PKG:-}}}"

if [ -n "$TARGET_PKG" ]; then
    echo "Filtering Phase 2: Only executing package matching '$TARGET_PKG'"
fi

for script in "${SCRIPTS[@]}"; do
    CURRENT_PKG_IDX=$((CURRENT_PKG_IDX + 1))
    SCRIPT_PKG_NAME=$(grep -E "^PKG_NAME=" "$script" | cut -d'"' -f2 || echo "")
    FILE_PKG_NAME=$(basename "$script" .sh)

    # Check if target package filter applies
    if [ -n "$TARGET_PKG" ]; then
        if [[ ! "$FILE_PKG_NAME" =~ "$TARGET_PKG" ]] && [[ ! "$SCRIPT_PKG_NAME" =~ "$TARGET_PKG" ]]; then
            # Skip silent to avoid noise
            continue
        fi
        echo "Found matching target package: $FILE_PKG_NAME"
    else
        # Standard build check only if no specific package was targeted
        if [[ -f "$STATE_DIR/${FILE_PKG_NAME}-temp.built" ]] || \
           [[ -n "$SCRIPT_PKG_NAME" && -f "$STATE_DIR/${SCRIPT_PKG_NAME}-temp.built" ]] || \
           [[ -n "$SCRIPT_PKG_NAME" && -f "$STATE_DIR/${SCRIPT_PKG_NAME}.built" ]]; then
            echo "__GINGER_PKG_COUNT__: $CURRENT_PKG_IDX/$TOTAL_PKGS : $FILE_PKG_NAME (Skipped)"
            continue
        fi
    fi

    echo "__GINGER_PKG_MARKER__: ${FILE_PKG_NAME}"
    echo "__GINGER_PKG_COUNT__: $CURRENT_PKG_IDX/$TOTAL_PKGS : $FILE_PKG_NAME"
    echo "Building: ${FILE_PKG_NAME} (Temporary Tools)"

    if bash "$script"; then
        touch "$STATE_DIR/${FILE_PKG_NAME}-temp.built"
        echo "Successfully built: ${FILE_PKG_NAME}"
        find ${LFS}/sources -mindepth 1 -maxdepth 1 -type d ! -name "build" -exec rm -rf {} +
    else
        echo "Error: Failed to build ${FILE_PKG_NAME}"
        exit 1
    fi
done

if [ -z "$TARGET_PKG" ]; then
    echo "Phase 2 Cross Tools Build Complete."
    mark_built "08_phase2_tools"
else
    echo "Single package build attempt completed for: $TARGET_PKG"
fi
