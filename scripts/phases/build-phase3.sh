# GingerOS - Phase 3 Orchestrator (Inside Chroot)

set -e
set -o pipefail

STATE_DIR="/ginger_os/.build_state"
mkdir -p "$STATE_DIR"

LOG_DIR="/var/log/ginger"
mkdir -p "$LOG_DIR"

echo "Inside Chroot: Starting Phase 3 (Final System Build)..."

SCRIPTS=(/scripts/phase3-system/*.sh)
TOTAL_PKGS=${#SCRIPTS[@]}
CURRENT_PKG_IDX=0

for script in "${SCRIPTS[@]}"; do
    CURRENT_PKG_IDX=$((CURRENT_PKG_IDX + 1))
    SCRIPT_PKG_NAME=$(grep -E "^PKG_NAME=" "$script" | cut -d'"' -f2 || echo "")
    FILE_PKG_NAME=$(basename "$script" .sh | cut -d'-' -f2-)
    FULL_SCRIPT_NAME=$(basename "$script" .sh)

    if [ -f "$STATE_DIR/${FULL_SCRIPT_NAME}.built" ]; then
        echo "__GINGER_PKG_COUNT__: $CURRENT_PKG_IDX/$TOTAL_PKGS : $FILE_PKG_NAME (Skipped)"
        continue
    fi

    if [[ ! "$FILE_PKG_NAME" =~ ^(gettext|bison|perl|python|texinfo|util-linux)$ ]]; then
        if [ -f "$STATE_DIR/${FILE_PKG_NAME}.built" ] || \
           [ -n "$SCRIPT_PKG_NAME" -a -f "$STATE_DIR/${SCRIPT_PKG_NAME}.built" ]; then
            echo "__GINGER_PKG_COUNT__: $CURRENT_PKG_IDX/$TOTAL_PKGS : $FILE_PKG_NAME (Skipped)"
            continue
        fi
    fi

    echo "__GINGER_PKG_MARKER__: $FILE_PKG_NAME"
    echo "__GINGER_PKG_COUNT__: $CURRENT_PKG_IDX/$TOTAL_PKGS : $FILE_PKG_NAME"
    echo "Building: $FILE_PKG_NAME (Final System)"

    if bash "$script"; then
        touch "$STATE_DIR/${FULL_SCRIPT_NAME}.built"
        echo "Successfully built: ${FILE_PKG_NAME}"
        find /sources -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
    else
        echo "Error: Failed to build ${FILE_PKG_NAME}"
        exit 1
    fi
done
