#!/bin/bash
# LFS 12.4 - 8.28. Shadow-4.18.0
source "/scripts/common.sh"
PKG_NAME="shadow"
ARCHIVE="shadow-4.18.0.tar.xz"
DIR_NAME="shadow-4.18.0"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find lib -name Makefile.in -exec sed -i 's/groups$(EXEEXT) //' {} +
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'      {} +
find man -name Makefile.in -exec sed -i 's/groups\.1\.xml / /'  {} +
sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD YESCRYPT@' \
       -e 's@/var/spool/mail@/var/mail@'                   \
       -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                  \
       etc/login.defs
./configure --sysconfdir=/etc   \
            --disable-static    \
            --with-group-name-max-length=32
make $MAKEFLAGS
make install
make libpwnam
pwconv
grpconv
mkdir -p /etc/default
useradd -D --shell /bin/bash
# No password set for root yet as per LFS instructions
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
