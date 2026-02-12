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

for script in "${SCRIPTS[@]}"; do
    PKG_NAME=$(basename "$script" .sh)
    
    echo "Building: $PKG_NAME (Temporary Tools)"

    # Check if already built
    if [ -f "/mnt/lfs/var/lib/ginger/$PKG_NAME-temp.built" ]; then
        echo "Package $PKG_NAME already built, skipping."
        continue
    fi

    # Run the build script
    if bash "$script"; then
        mkdir -p "/mnt/lfs/var/lib/ginger"
        touch "/mnt/lfs/var/lib/ginger/$PKG_NAME-temp.built"
        echo "Successfully built: $PKG_NAME"
    else
        echo "Error: Failed to build $PKG_NAME"
        exit 1
    fi
done

echo "Phase 2 Cross Tools Build Complete."
