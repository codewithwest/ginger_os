#!/bin/bash
# GingerOS - Enable comfortable, Zsh-like interactive Bash defaults.
source "/lfs/lib/common.sh"
PKG_NAME="ginger-bash-experience"
check_built "$PKG_NAME" && exit 0

log "INFO" "Installing GingerOS interactive Bash defaults..."

install -D -m 0644 /lfs/phase3-system/ginger-bashrc /etc/skel/.bashrc
install -D -m 0644 /lfs/phase3-system/ginger-bash-profile.sh /etc/profile.d/ginger-bash.sh

mark_built "$PKG_NAME"
