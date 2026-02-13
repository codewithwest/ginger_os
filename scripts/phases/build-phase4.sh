#!/bin/bash
# GingerOS - Phase 4 Orchestrator (Kernel & Boot)
# Runs inside the chroot environment

set -e
set -o pipefail

echo "Inside Chroot: Starting Phase 4 (Kernel & Boot)..."

# Collect scripts - and ensure they follow the GINGER_PKG pattern for the engine
SCRIPTS=(/scripts/phase4-boot/*.sh)

for script in "${SCRIPTS[@]}"; do
    PKG_NAME=$(basename "$script" .sh | cut -d'-' -f2-)
    
    echo "GINGER_PKG: $PKG_NAME"
    echo "Building: $PKG_NAME (Boot Components)"

    # Skip if already built
    if [ -f "/var/lib/ginger/$PKG_NAME.built" ]; then
        echo "$PKG_NAME already built, skipping."
        continue
    fi

    # Execute
    if bash "$script"; then
        mkdir -p "/var/lib/ginger"
        touch "/var/lib/ginger/$PKG_NAME.built"
        echo "Successfully built: $PKG_NAME"
        # Safe cleanup: only folders, preserve archives
        find /sources -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
    else
        echo "Error: Failed to build $PKG_NAME"
        exit 1
    fi
done

echo "Phase 4 Kernel & Boot Build Complete."
