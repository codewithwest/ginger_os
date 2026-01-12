#!/bin/bash
# LFS 12.4 - 8.4. Iana-Etc-20250807
# Provides data for network services and protocols.

source "/scripts/common.sh"

PKG_NAME="iana-etc"
ARCHIVE="iana-etc-20250807.tar.gz"
DIR_NAME="iana-etc-20250807"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

log "PROCESS" "Installing Iana-Etc..."
cp services protocols /etc

cd ..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
