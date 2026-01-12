#!/bin/bash
# LFS 12.4 - 8.44. XML-Parser-2.47
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="xml-parser"
check_built "$PKG_NAME" && exit 0
extract "XML-Parser"
perl Makefile.PL
make $MAKEFLAGS
make install
cd .. && rm -rf "XML-Parser-"*
mark_built "$PKG_NAME"
