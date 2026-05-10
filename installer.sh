#!/bin/bash
# GingerOS - Entry point for the installer service
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
sudo bash "$SCRIPT_DIR/lfsiso/installer.sh" "$@"
