#!/bin/bash
# GingerOS - Phase 4 Orchestrator (Kernel & Boot)
# Runs inside the chroot environment

set -e
set -o pipefail

echo "Inside Chroot: Starting Phase 4 (Kernel & Boot)..."

# Collect scripts - and ensure they follow the GINGER_PKG pattern for the engine
SCRIPTS=(/scripts/phase4-boot/*.sh)

for script in "${SCRIPTS[@]}"; do
    SCRIPT_PKG_NAME=$(grep -E "^PKG_NAME=" "$script" | cut -d'"' -f2 || echo "")
    FILE_PKG_NAME=$(basename "$script" .sh | cut -d'-' -f2-)
    
    # Skip if already built
    if [ -f "/var/lib/ginger/${FILE_PKG_NAME}.built" ] || \
       [ -n "$SCRIPT_PKG_NAME" -a -f "/var/lib/ginger/${SCRIPT_PKG_NAME}.built" ]; then
        continue
    fi

    echo "__GINGER_PKG_MARKER__: $FILE_PKG_NAME"
    echo "Building: $FILE_PKG_NAME (Boot Components)"

    # Execute
    if bash "$script"; then
        mkdir -p "/var/lib/ginger"
        touch "/var/lib/ginger/${FILE_PKG_NAME}.built"
        echo "Successfully built: ${FILE_PKG_NAME}"
        # Safe cleanup: only folders, preserve archives
        find /sources -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
    else
        echo "Error: Failed to build ${FILE_PKG_NAME}"
        exit 1
    fi
done

echo "Phase 4 Kernel & Boot Build Complete."
