#!/bin/bash
set -e

export LFS=${LFS}
IMAGE=/opt/ginger_os/ginger_os.img

LOOP=$(losetup -fP --show "$IMAGE")
mount "${LOOP}p1" "$LFS"

echo "LFS mounted at $LFS using $LOOP"
df -h "$LFS"
