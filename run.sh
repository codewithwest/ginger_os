#!/bin/bash
# GingerOS Runner
# Automatically uses the virtual environment

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Sync dependencies via uv before launching
uv sync --project "$SCRIPT_DIR" --quiet

source "$SCRIPT_DIR/.venv/bin/activate"
python3 "$SCRIPT_DIR/ginger_os.py" "$@"
