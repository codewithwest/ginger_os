#!/bin/bash
# LFS 12.4 - 8.16. Tcl-8.6.16
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="tcl"
check_built "$PKG_NAME" && exit 0

# Tcl is a bit unique with its archive name and sub-directory
extract "tcl"
# The extract function should handle the -src suffix and cd into unix/
cd unix

./configure --prefix=/usr           \
            --with-system-libtoml   \
            --enable-threads        \
            --mandir=/usr/share/man

make $MAKEFLAGS

sed -e "s#$GINGER_ROOT/build/tcl$TCL_VERSION/unix#/usr/lib#" \
    -e "s#$GINGER_ROOT/build/tcl$TCL_VERSION#/usr/include#" \
    -i tclConfig.sh

sed -e "s#$GINGER_ROOT/build/tcl$TCL_VERSION/unix/pkgs/itcl[0-9.]*#/usr/lib/itcl[0-9.]*#" \
    -e "s#$GINGER_ROOT/build/tcl$TCL_VERSION/pkgs/itcl[0-9.]*#/usr/include#" \
    -e "s#$GINGER_ROOT/build/tcl$TCL_VERSION/unix#/usr/include#" \
    -i pkgs/itcl[0-9.]*/itclConfig.sh

sed -e "s#$GINGER_ROOT/build/tcl$TCL_VERSION/unix/pkgs/tdbc[0-9.]*#/usr/lib/tdbc[0-9.]*#" \
    -e "s#$GINGER_ROOT/build/tcl$TCL_VERSION/pkgs/tdbc[0-9.]*#/usr/include#" \
    -e "s#$GINGER_ROOT/build/tcl$TCL_VERSION/unix#/usr/include#" \
    -i pkgs/tdbc[0-9.]*/tdbcConfig.sh

make install
chmod -v u+w /usr/lib/libtcl8.6.so
make install-private-headers
ln -sfv tclsh8.6 /usr/bin/tclsh

cd ../.. && rm -rf "tcl"*
mark_built "$PKG_NAME"
