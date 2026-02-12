#!/bin/bash
# Quick test of the updated UI

cd "$(dirname "$0")"
source "../lib/ui.sh"

export UI_LOG_FILE="/tmp/ui_test.log"
: > "$UI_LOG_FILE"

# Initialize with 6 steps
ui_init "Download" "Extract" "Configure" "Build" "Test" "Install"

# Simulate step 1 with logs
ui_step 0 "Downloading packages..."

for i in {1..15}; do
    echo "[$(date +'%H:%M:%S')] [$i/15] Downloading: package-$i.tar.gz (Sequential Mode)..." >> "$UI_LOG_FILE"
    sleep 0.5
done

ui_step 1 "Extracting..."
echo "[$(date +'%H:%M:%S')] Extraction complete" >> "$UI_LOG_FILE"
sleep 2

ui_finish

echo
echo "Test complete! The UI should have shown:"
echo "  - Max 6 steps visible"
echo "  - Max 10 log lines"
echo "  - Each log on its own line"
