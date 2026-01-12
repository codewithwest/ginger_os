#!/bin/bash
# LFS 12.4 - 8.16. Tcl-8.6.16
source "/scripts/common.sh"
PKG_NAME="tcl"
ARCHIVE="tcl8.6.16-src.tar.gz"
DIR_NAME="tcl8.6.16"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
SRCDIR=$(pwd)
cd unix
./configure --prefix=/usr           \
            --mandir=/usr/share/man
make $MAKEFLAGS
sed -e "s|$SRCDIR/unix|/usr/lib|" \
    -e "s|$SRCDIR|/usr/include|"  \
    -i tclConfig.sh
sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.10|/usr/lib/tdbc1.1.10|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.10|/usr/include|"              \
    -i pkgs/tdbc1.1.10/tdbcConfig.sh
sed -e "s|$SRCDIR/unix/pkgs/itcl4.3.0|/usr/lib/itcl4.3.0|" \
    -e "s|$SRCDIR/pkgs/itcl4.3.0|/usr/include|"            \
    -i pkgs/itcl4.3.0/itclConfig.sh
unset SRCDIR
make install
chmod -v u+w /usr/lib/libtcl8.6.so
make install-private-headers
ln -sfv tclsh8.6 /usr/bin/tclsh
# Install documentation
mkdir -v -p /usr/share/man/mann
cp -v ../doc/*.n /usr/share/man/mann
cd ../..
rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
