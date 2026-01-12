#!/bin/bash
# LFS 12.4 - 8.77. Udev-257.8 (from Systemd)
source "/scripts/common.sh"
PKG_NAME="udev"
ARCHIVE="systemd-257.8.tar.gz"
DIR_NAME="systemd-257.8"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
sed -i -e 's/ gnu-efi//' -e 's/ bootctl//' meson.build
mkdir -v build
cd build
meson setup ..                  \
      --prefix=/usr             \
      --buildtype=release       \
      -Ddefault-library=shared  \
      -Dacl=true                \
      -Dkmod=true               \
      -Dopenssl=true            \
      -Dblkid=true              \
      -Dlz4=true                \
      -Dzstd=true               \
      -Dmode=release            \
      -Dpam=false               \
      -Dselinux=false           \
      -Daudit=false             \
      -Dman=false               \
      -Dtests=false             \
      -Drootprefix=""           \
      -Dudev=true               \
      -Dinstall-tests=false
ninja udevadm systemd-hwdb \
      $(grep -oP "['\s\/]libudev\.(so|a)\.[0-9.]*" ../meson.build | tr -d "'") \
      $(grep -oP "['\s\/]udev\.[0-9.]*" ../meson.build | tr -d "'")
install -vm755 udevadm /usr/bin/
install -vm755 systemd-hwdb /usr/bin/udev-hwdb
# Additional udev setup per LFS logic...
cd ../.. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
