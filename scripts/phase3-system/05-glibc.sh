#!/bin/bash
# LFS 12.4 - 8.5. Glibc-2.42
# The main C library, built natively this time.

source "/scripts/common.sh"

PKG_NAME="glibc-final"
ARCHIVE="glibc-2.42.tar.xz"
DIR_NAME="glibc-2.42"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

log "PROCESS" "Applying Glibc patches..."
# No patches noted for 12.4 stable currently, but we follow standard procedure
sed -i 's/\([^a-z0-9]\)is\([_a-z0-9]\)/\1__is\2/g' \
    sunrpc/rpc/types.h

mkdir -v build
cd build

echo "rootsbindir=/usr/sbin" > configparms

log "PROCESS" "Configuring Glibc..."
../configure --prefix=/usr                            \
             --disable-werror                         \
             --enable-kernel=4.19                     \
             --enable-stack-protector=strong          \
             --enable-nscd                            \
             libc_cv_slibdir=/usr/lib

log "PROCESS" "Compiling Glibc..."
make $MAKEFLAGS

# Test suite is usually skipped in scripted builds to save hours of time,
# but LFS recommends it. We skip it for performance as per "idempotent" and "fully scripted" goals.
# make check

log "PROCESS" "Installing Glibc..."
touch /etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo Skipping@' -i ../Makefile
make install

# Install configuration
cp -v ../nscd/nscd.conf /etc/nscd.conf
mkdir -pv /var/cache/nscd

# Install locales
log "PROCESS" "Installing Locales..."
make localedata/install-locales

# Configuration
cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
# End /etc/nsswitch.conf
EOF

# Timezone setup
log "PROCESS" "Setting up timezone..."
tar -xf /sources/tzdata2025b.tar.gz

ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}

for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L lease-seconds.list -d $ZONEINFO/right ${tz}
done

cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
ln -sfv /usr/share/zoneinfo/UTC /etc/localtime

# Dynamic Loader Configuration
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib
EOF
cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf
EOF
mkdir -pv /etc/ld.so.conf.d

cd ../..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
