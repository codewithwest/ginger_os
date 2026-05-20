#!/bin/bash
# GingerOS Unified Runner

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "======================================================================"
print_cyan() {
    echo -e "\033[36m$1\033[0m"
}

print_cyan "🚀 Launching GingerOS Development Environment..."
echo "======================================================================"

# 1. Spin up the FastAPI server inside our virtual environment
print_cyan "⚙️  Starting build engine server..."
"$SCRIPT_DIR/.venv/bin/python3" "$SCRIPT_DIR/server/main.py" > "$SCRIPT_DIR/backend.log" 2>&1 &
SERVER_PID=$!

cleanup() {
    echo ""
    print_cyan "🔌 Stopping backend engine server..."
    kill $SERVER_PID 2>/dev/null || true
}
trap cleanup EXIT

# Wait briefly for backend to bind port
sleep 1.2

# 2. Build and launch our high-performance Go TUI
print_cyan "🛸 Booting high-density Go HUD..."
cd "$SCRIPT_DIR/ui/gotui"
go build -o ginger-hud .
./ginger-hud

echo "======================================================================"
print_cyan "🏁 Environment closed."
echo "======================================================================"