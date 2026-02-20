#!/bin/bash
# GingerOS - Phase 2 Orchestrator
# Runs inside the LFS user environment

set -e
set -o pipefail

# Calculate script directory
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PHASE2_TOOLS_DIR="$SCRIPT_DIR/../phase2-tools"

# Collect scripts
SCRIPTS=("$PHASE2_TOOLS_DIR"/*.sh)
TOTAL_PKGS=${#SCRIPTS[@]}
CURRENT_PKG_IDX=0

for script in "${SCRIPTS[@]}"; do
    CURRENT_PKG_IDX=$((CURRENT_PKG_IDX + 1))
    SCRIPT_PKG_NAME=$(grep -E "^PKG_NAME=" "$script" | cut -d'"' -f2 || echo "")
    FILE_PKG_NAME=$(basename "$script" .sh)
    
    # Check both names for consistency (noting Phase 2 often uses -temp suffix)
    if [[ -f "/mnt/lfs/var/lib/ginger/${FILE_PKG_NAME}-temp.built" ]] || \
       [[ -n "$SCRIPT_PKG_NAME" && -f "/mnt/lfs/var/lib/ginger/${SCRIPT_PKG_NAME}-temp.built" ]] || \
       [[ -n "$SCRIPT_PKG_NAME" && -f "/mnt/lfs/var/lib/ginger/${SCRIPT_PKG_NAME}.built" ]]; then
        echo "__GINGER_PKG_COUNT__: $CURRENT_PKG_IDX/$TOTAL_PKGS : $FILE_PKG_NAME (Skipped)"
        continue
    fi
    
    echo "__GINGER_PKG_MARKER__: ${FILE_PKG_NAME}"
    echo "__GINGER_PKG_COUNT__: $CURRENT_PKG_IDX/$TOTAL_PKGS : $FILE_PKG_NAME"
    echo "Building: ${FILE_PKG_NAME} (Temporary Tools)"

    # Run the build script
    if bash "$script"; then
        mkdir -p "/mnt/lfs/var/lib/ginger"
        touch "/mnt/lfs/var/lib/ginger/${FILE_PKG_NAME}-temp.built"
        echo "Successfully built: ${FILE_PKG_NAME}"
        # Cleanup sources to save space
        find /mnt/lfs/sources -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
    else
        echo "Error: Failed to build ${FILE_PKG_NAME}"
        exit 1
    fi
done

echo "Phase 2 Cross Tools Build Complete."
