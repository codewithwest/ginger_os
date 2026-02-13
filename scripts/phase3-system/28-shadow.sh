#!/bin/bash
# LFS 12.4 - 8.28. Shadow-4.17.3
source "/scripts/lib/common.sh"
PKG_NAME="shadow"
check_built "$PKG_NAME" && exit 0
extract "shadow"

sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;

sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
    -e 's:/var/spool/mail:/var/mail:'                   \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                  \
    -i etc/login.defs

touch /usr/bin/passwd
./configure --sysconfdir=/etc   \
            --disable-static    \
            --with-{b,yes}crypt \
            --without-libbsd    \
            --with-group-name-max-length=32

make $MAKEFLAGS

make exec_prefix=/usr install
make -C man install-man

# Initialize password aging
hash -r
pwconv
grpconv

# Ensure the 'users' group exists before setting it as the default
grep -q '^users:' /etc/group || groupadd -g 999 users

mkdir -p /etc/default
useradd -D --gid 999

cleanup
mark_built "$PKG_NAME"
# Note: Root password must be set manually or via another script
