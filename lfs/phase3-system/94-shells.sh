#!/bin/bash
# GingerOS - Valid Login Shells (LFS 12.4 - Section 7.9)
source "/lfs/lib/common.sh"
PKG_NAME="shells"
check_built "$PKG_NAME" && exit 0

log "INFO" "Creating /etc/shells..."

# 7.9. Creating the /etc/shells File
cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF

mark_built "$PKG_NAME"
