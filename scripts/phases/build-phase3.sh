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
    PKG_NAME=$(basename "$script" .sh | cut -d'-' -f2-)

    echo "GINGER_PKG: $PKG_NAME"
    echo "Building: $PKG_NAME (Final System)"

    if [ -f "/var/lib/ginger/$PKG_NAME.built" ]; then
        echo "$PKG_NAME already built, skipping."
        continue
    fi

    if bash "$script"; then
        mkdir -p "/var/lib/ginger"
        touch "/var/lib/ginger/$PKG_NAME.built"
        echo "Successfully built: $PKG_NAME"
    else
        echo "Error: Failed $PKG_NAME"
        exit 1
    fi
done
