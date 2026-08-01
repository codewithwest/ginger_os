#!/bin/bash
# LFS 13.0 - systemd-259.1
source "/lfs/lib/common.sh"
PKG_NAME="systemd"
check_built "$PKG_NAME" && exit 0
extract "systemd"

ln -sf /proc/self/mounts /etc/mtab

sed -e 's/GROUP="render"/GROUP="video"/' \
    -e 's/GROUP="sgx", //'               \
    -i rules.d/50-udev-default.rules.in

sed -i '/systemd-sysctl/s/^/#/' rules.d/99-systemd.rules.in

mkdir -p build
cd       build

meson setup ..                \
      --prefix=/usr           \
      --buildtype=release     \
      -D default-dnssec=no    \
      -D firstboot=false      \
      -D install-tests=false  \
      -D ldconfig=false       \
      -D sysusers=false       \
      -D rpmmacrosdir=no      \
      -D homed=disabled       \
      -D man=disabled         \
      -D mode=release         \
      -D pamconfdir=no        \
      -D dev-kvm-mode=0660    \
      -D nobody-group=nogroup \
      -D sysupdate=disabled   \
      -D ukify=disabled       \
      -D libdir=/usr/lib      \
      -D docdir=/usr/share/doc/systemd-259.1

ninja $MAKEFLAGS
ninja install

rm -rf /usr/share/man/man*/systemd*

systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
systemctl enable getty@tty1
systemd-machine-id-setup

cd ../.. && cleanup
mark_built "$PKG_NAME"
