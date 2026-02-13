# GingerOS - Phase 3 Orchestrator (Inside Chroot)

set -e
set -o pipefail

LOG_DIR="/var/log/ginger"
mkdir -p "$LOG_DIR"

echo "Inside Chroot: Starting Phase 3 (Final System Build)..."

# Map scripts to 5 dashboard steps
get_phase3_idx() {
    local num=$(echo "$1" | cut -d'-' -f1 | sed 's/^0//')
    if [ "$num" -le 10 ]; then echo 0
    elif [ "$num" -le 35 ]; then echo 1
    elif [ "$num" -le 65 ]; then echo 2
    elif [ "$num" -le 85 ]; then echo 3
    else echo 4
    fi
}

SCRIPTS=(/scripts/phase3-system/*.sh)
for script in "${SCRIPTS[@]}"; do
    SCRIPT_PKG_NAME=$(grep -E "^PKG_NAME=" "$script" | cut -d'"' -f2 || echo "")
    FILE_PKG_NAME=$(basename "$script" .sh | cut -d'-' -f2-)
    
    FULL_SCRIPT_NAME=$(basename "$script" .sh)
    
    # Priority 1: Check for unique script-based marker (The Gold Standard)
    if [ -f "/var/lib/ginger/${FULL_SCRIPT_NAME}.built" ]; then
        continue
    fi

    # Priority 2: Fallback to generic markers ONLY if no known collision with bridge tools
    if [[ ! "$FILE_PKG_NAME" =~ ^(gettext|bison|perl|python|texinfo|util-linux)$ ]]; then
        if [ -f "/var/lib/ginger/${FILE_PKG_NAME}.built" ] || \
           [ -n "$SCRIPT_PKG_NAME" -a -f "/var/lib/ginger/${SCRIPT_PKG_NAME}.built" ]; then
            continue
        fi
    fi

    echo "__GINGER_PKG_MARKER__: $FILE_PKG_NAME"
    echo "Building: $FILE_PKG_NAME (Final System)"

    if bash "$script"; then
        mkdir -p "/var/lib/ginger"
        touch "/var/lib/ginger/${FULL_SCRIPT_NAME}.built"
        echo "Successfully built: ${FILE_PKG_NAME}"
        # Cleanup sources to save space
        find /sources -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
    else
        echo "Error: Failed to build ${FILE_PKG_NAME}"
        exit 1
    fi
done
