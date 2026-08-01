#!/bin/bash
# GingerOS - Bash Shell Startup Files (LFS 13.0 - Section 7.7)
source "/lfs/lib/common.sh"
PKG_NAME="shell-profile"
check_built "$PKG_NAME" && exit 0

log "INFO" "Configuring global shell profile..."

# 7.7. The Bash Shell Startup Files
# We use en_US.UTF-8 as the default modern locale.
cat > /etc/profile << "EOF"
# Begin /etc/profile

export LANG=en_US.UTF-8

# End /etc/profile
EOF

mark_built "$PKG_NAME"
