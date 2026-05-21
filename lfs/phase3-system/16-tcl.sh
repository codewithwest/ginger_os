#!/bin/bash
# LFS 13.0  - 8.16. Tcl-8.6.16
source "/lfs/lib/common.sh"
PKG_NAME="tcl"
check_built "$PKG_NAME" && exit 0

# Tcl is a bit unique with its archive name and sub-directory
extract "tcl*-src"
# The extract function should handle the -src suffix and cd into unix/
SRCDIR=$(pwd)

cd unix

./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --disable-rpath

make

sed -e "s|$SRCDIR/unix|/usr/lib|" \
    -e "s|$SRCDIR|/usr/include|"  \
    -i tclConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.12|/usr/lib/tdbc1.1.12|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.12/generic|/usr/include|"     \
    -e "s|$SRCDIR/pkgs/tdbc1.1.12/library|/usr/lib/tcl8.6|"  \
    -e "s|$SRCDIR/pkgs/tdbc1.1.12|/usr/include|"             \
    -i pkgs/tdbc1.1.12/tdbcConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/itcl4.3.4|/usr/lib/itcl4.3.4|" \
    -e "s|$SRCDIR/pkgs/itcl4.3.4/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/itcl4.3.4|/usr/include|"            \
    -i pkgs/itcl4.3.4/itclConfig.sh

unset SRCDIR

make install
chmod 644 /usr/lib/libtclstub8.6.a

chmod -v u+w /usr/lib/libtcl8.6.so

make install-private-headers

ln -sfv tclsh8.6 /usr/bin/tclsh

mv /usr/share/man/man3/{Thread,Tcl_Thread}.3

cd ..
# tar -xf ../tcl8.6.16-html.tar.gz --strip-components=1
# mkdir -v -p /usr/share/doc/tcl-8.6.16
# cp -v -r  ./html/* /usr/share/doc/tcl-8.6.16


cd ../.. && cleanup
mark_built "$PKG_NAME"
