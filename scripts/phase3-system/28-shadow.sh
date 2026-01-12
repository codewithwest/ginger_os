#!/bin/bash
# LFS 12.4 - 8.28. Shadow-4.17.3
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="shadow"
check_built "$PKG_NAME" && exit 0
extract "shadow"
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;

sed -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD YESCRYPT@' \
    -e 's@/var/spool/mail@/var/mail@'                   \
    -e '/SUBID_[GU]ID_MIN/s/100000/65536/'              \
    -i etc/login.defs

./configure --sysconfdir=/etc   \
            --disable-static    \
            --with-group-name-max-length=32
make $MAKEFLAGS
make exec_prefix=/usr install
make -C man install-man

# Initialize password aging
pwconv
grpconv
mkdir -p /etc/default
useradd -D --gid 999

cd .. && rm -rf "shadow-"*
mark_built "$PKG_NAME"
# Note: Root password must be set manually or via another script
