#!/bin/bash
# GingerOS - Mount Chroot (Stage 5)
# MUST BE RUN AS ROOT

set -e

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

log "INFO" "Setting up virtual kernel file systems and binding directories..."
sudo bash "${SCRIPT_DIR}/../chroot.sh" --mount-only

log "INFO" "Chroot mounts successful."
mark_built "09_chroot_mounts"
