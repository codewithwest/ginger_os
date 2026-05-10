#!/bin/bash
# GingerOS - Entry point for ISO generation
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
sudo bash "$SCRIPT_DIR/lfsiso/make-iso.sh" "$@"
