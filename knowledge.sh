#!/usr/bin/env bash
set -e
source .venv/bin/activate
python -m llm.chatbot.knowledge_ingest
python -m llm.chatbot.knowledge_ingest_repo
echo "Knowledge base refreshed"