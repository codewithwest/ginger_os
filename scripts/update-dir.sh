#!/bin/bash
# GingerOS - Update Directory Script
# set lfs
LFS=/mnt/lfs
source "$(dirname "$(readlink -f "$0")")/../common.sh"

mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}

for i in bin lib sbin; do
  ln -sv usr/$i $LFS/$i
done

case $(uname -m) in
  x86_64) mkdir -pv $LFS/lib64 ;;
esac

mkdir -pv $LFS/tools

mkdir /mnt/lfs/var/lib/ginger/
chown -v lfs $LFS/{usr{,/*},var,etc,tools}
case $(uname -m) in
  x86_64) chown -v lfs $LFS/lib64 ;;
esac

chown -v lfs $LFS/var/lib/ginger/
su - lfs
