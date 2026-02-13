#!/bin/bash
# GingerOS - Phase 1 Orchestrator
# Runs inside the LFS user environment

set -e
set -o pipefail

# Calculate script directory
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PHASE1_TOOLS_DIR="$SCRIPT_DIR/../phase1-tools"

# Collect scripts
SCRIPTS=("$PHASE1_TOOLS_DIR"/*.sh)

# Note: We just print status lines that the Main Orchestrator will log.
# We don't use the full UI library here because the LFS user environment is minimal.

for script in "${SCRIPTS[@]}"; do
    PKG_NAME=$(basename "$script" .sh)
    
    echo "GINGER_PKG: $PKG_NAME"
    echo "Building: $PKG_NAME"

    # Check if already built
    if [ -f "/mnt/lfs/var/lib/ginger/$PKG_NAME.built" ]; then
        echo "Package $PKG_NAME already built, skipping."
        continue
    fi

    # Run the build script
    if bash "$script"; then
        mkdir -p "/mnt/lfs/var/lib/ginger"
        touch "/mnt/lfs/var/lib/ginger/$PKG_NAME.built"
        echo "Successfully built: $PKG_NAME"
        # Call cleanup from common.sh if it was sourced in the child, 
        # but since we run in a subshell, we'll manually clean up here too 
        # or ensure the child does it. Actually, better to have the orchestrator
        # ensure cleanup of whatever was left in /mnt/lfs/sources.
        find /mnt/lfs/sources -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
    else
        echo "Error: Failed to build $PKG_NAME"
        exit 1
    fi
done

echo "Phase 1 Toolchain Build Complete."