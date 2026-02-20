#!/bin/bash
# LFS 12.4 - 7.5. Creating Directories
# To be run INSIDE chroot.

source "/scripts/lib/common.sh"

log "INFO" "Creating standard directory tree..."

mkdir -pv /{boot,home,mnt,opt,srv}
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{local/{bin,include,lib,sbin,src},share/{doc,info,locale,man},src}
mkdir -pv /usr/share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}

ln -sfv /run /var/run
ln -sfv /run/lock /var/lock

install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

log "INFO" "Directories created."
