#!/bin/bash
# LFS 12.4 - 8.76. Jinja2-3.1.6
source "/scripts/common.sh"
PKG_NAME="jinja2"
check_built "$PKG_NAME" && exit 0
extract "jinja2"
python3 setup.py build
python3 setup.py install --root dest
cp -rv dest/* /
cd .. && rm -rf "jinja2-"*
mark_built "$PKG_NAME"
