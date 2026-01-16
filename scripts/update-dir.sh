#!/bin/bash
# GingerOS - Update Directory Script
# set lfs
LFS=/mnt/lfs
source "$(dirname "$(readlink -f "$0")")/common.sh"

mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}

# create symlinks for bin, lib, sbin
for i in bin lib sbin; do
  if [ -L "$LFS/$i" ]; then
    echo "Symlink $LFS/$i already exists — skipping"
  elif [ -d "$LFS/$i" ]; then
    echo "Replacing directory $LFS/$i with symlink"
    rm -rf "$LFS/$i"
    ln -sv "usr/$i" "$LFS/$i"
  else
    ln -sv "usr/$i" "$LFS/$i"
  fi
done

case $(uname -m) in
  x86_64) mkdir -pv $LFS/lib64 ;;
esac

mkdir -pv $LFS/tools

mkdir -pv $LFS/var/lib/ginger/
chown -v lfs $LFS/{usr{,/*},var,etc,tools}
case $(uname -m) in
  x86_64) chown -v lfs $LFS/lib64 ;;
esac

chown -v lfs "$LFS/var"
chown -v lfs "$LFS/var/lib"
chown -R lfs "$LFS/var/lib/ginger"

chmod -R 777 "$GINGER_LOGS"