#!/bin/bash
# GingerOS - Host setup
# MUST BE RUN AS ROOT

source "$(dirname "$(readlink -f "$0")")/../config/env.sh"
source "$(dirname "$(readlink -f "$0")")/common.sh"

log "INFO" "Ensuring $LFS exists and has correct permissions..."
mkdir -p "$LFS"
# Ensure the lfs user owns the entire mount point
chown -R lfs:lfs "$LFS"

# Note: Ideally $LFS is a mount point. We don't want to fill up the host root.
if [ "$(stat -c %d /)" == "$(stat -c %d "$LFS")" ]; then
    log "WARN" "$LFS is on the root partition. It is highly recommended to use a separate partition."
fi

mkdir -pv "$LFS/sources"
mkdir -pv "$LFS/tools"
mkdir -pv "$LFS/usr/include"

# Copy sources to $LFS/sources if they exist
if [ -d "$GINGER_SOURCES" ] && [ "$(ls -A "$GINGER_SOURCES")" ]; then
    log "INFO" "Copying existing sources to $LFS/sources..."
    cp -r "$GINGER_SOURCES/"* "$LFS/sources/"
else
    log "WARN" "No sources found in $GINGER_SOURCES. Run download.sh later."
fi
chmod -v a+wt "$LFS/sources"

# Create lfs user
if ! id lfs >/dev/null 2>&1; then
    log "INFO" "Creating 'lfs' user..."
    # Using absolute paths as some minimal systems have restricted PATHs even for sudo
    /usr/sbin/groupadd lfs
    /usr/sbin/useradd -s /bin/bash -g lfs -m -k /dev/null lfs
    echo "lfs:lfs" | /usr/sbin/chpasswd
fi

chown -v lfs "$LFS/tools"
chown -v lfs "$LFS/sources"
chown -v lfs "$LFS/usr/include"
mkdir -pv "$LFS/var/lib/ginger"
chown -R lfs "$LFS/var/lib/ginger"

log "INFO" "Host setup complete. Swaping to 'lfs' user to begin Phase 1."
