#!/bin/bash
# GingerOS - Update Directory Script
# set lfs
LFS=/mnt/lfs
source "$(dirname "$(readlink -f "$0")")/../common.sh"

# Update the directory
chown -v lfs $LFS/{usr{,/*},var,etc,tools}
case $(uname -m) in
  x86_64) chown -v lfs $LFS/lib64 ;;
esac

su - lfs
