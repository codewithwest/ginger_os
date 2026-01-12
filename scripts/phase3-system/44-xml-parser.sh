#!/bin/bash
# LFS 12.4 - 8.44. XML-Parser-2.47
source "/scripts/common.sh"
PKG_NAME="xml-parser"
ARCHIVE="XML-Parser-2.47.tar.gz"
DIR_NAME="XML-Parser-2.47"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
perl Makefile.PL
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
