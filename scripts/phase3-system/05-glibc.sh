#!/bin/bash
# LFS 12.4 - 8.5. Glibc-2.42
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="glibc-final"
check_built "$PKG_NAME" && exit 0
extract "glibc"

# FHS patch (if present)
if [ -f "$GINGER_SOURCES/glibc-2.42-fhs-1.patch" ]; then
    patch -Np1 -i "$GINGER_SOURCES/glibc-2.42-fhs-1.patch"
fi

mkdir -v build
cd build

echo "rootsbindir=/usr/sbin" > configparms

../configure --prefix=/usr                            \
             --disable-profile                        \
             --enable-add-ons                         \
             --enable-kernel=4.19                     \
             --enable-stack-protector=strong          \
             --enable-stackgroup                      \
             --disable-nscd                           \
             libc_cv_slibdir=/usr/lib

make $MAKEFLAGS

# Optional: make check
# (Takes a long time, skipping for automation)

make install

# Fix ldd path
sed -i 's|/usr/bin/perl|/usr/bin/env perl|' /usr/bin/ldd

# Install configurations
mkdir -pv /etc/ld.so.conf.d
cat > /etc/ld.so.conf << "EOF"
/usr/local/lib
/opt/lib
include /etc/ld.so.conf.d/*.conf
EOF

cd ../.. && rm -rf "glibc-"*
mark_built "$PKG_NAME"
