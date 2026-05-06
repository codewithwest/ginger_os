#!/usr/bin/env bash
set -e
source .venv/bin/activate
python -m lfs_builder_ui.knowledge_ingest
python -m lfs_builder_ui.knowledge_ingest_repo
python - <<'PY'
from lfs_builder_ui.chatbot import merged
# (re‑merge if you keep separate indexes)
PY
echo "Knowledge base refreshed"