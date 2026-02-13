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
    # derive internal PKG_NAME from the script file if possible for better matching
    # otherwise fallback to filename
    SCRIPT_PKG_NAME=$(grep -E "^PKG_NAME=" "$script" | cut -d'"' -f2 || echo "")
    FILE_PKG_NAME=$(basename "$script" .sh)
    
    # Check both names for consistency
    if [[ -f "/mnt/lfs/var/lib/ginger/${FILE_PKG_NAME}.built" ]] || \
       [[ -n "$SCRIPT_PKG_NAME" && -f "/mnt/lfs/var/lib/ginger/${SCRIPT_PKG_NAME}.built" ]]; then
        continue
    fi
    
    echo "__GINGER_PKG_MARKER__: $FILE_PKG_NAME"
    echo "Building: $FILE_PKG_NAME"

    # Run the build script
    if bash "$script"; then
        mkdir -p "/mnt/lfs/var/lib/ginger"
        touch "/mnt/lfs/var/lib/ginger/${FILE_PKG_NAME}.built"
        echo "Successfully built: ${FILE_PKG_NAME}"
        # Call cleanup from common.sh if it was sourced in the child, 
        # but since we run in a subshell, we'll manually clean up here too 
        # or ensure the child does it. Actually, better to have the orchestrator
        # ensure cleanup of whatever was left in /mnt/lfs/sources.
        find /mnt/lfs/sources -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
    else
        echo "Error: Failed to build ${FILE_PKG_NAME}"
        exit 1
    fi
done

echo "Phase 1 Toolchain Build Complete."