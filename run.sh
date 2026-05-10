#!/bin/bash
# GingerOS Runner

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source "$SCRIPT_DIR/.venv/bin/activate"

uv sync --project "$SCRIPT_DIR" --quiet

cd "$SCRIPT_DIR/ui/web"
npm run build

cd "$SCRIPT_DIR"

python3 -m ui.tui.main "$@"