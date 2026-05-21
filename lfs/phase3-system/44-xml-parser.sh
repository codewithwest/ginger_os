#!/bin/bash
# LFS 13.0  - 8.44. XML-Parser-2.47
source "/lfs/lib/common.sh"
PKG_NAME="xml-parser"
check_built "$PKG_NAME" && exit 0
extract "XML-Parser"

perl Makefile.PL


make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
