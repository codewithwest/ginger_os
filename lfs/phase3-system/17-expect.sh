#!/bin/bash
# LFS 12.4 - 8.17. Expect-5.45.4
source "/lfs/lib/common.sh"
PKG_NAME="expect"
check_built "$PKG_NAME" && exit 0
extract "expect"

# Test PTY support (non-critical - just warn if unavailable)
python3 -c 'from pty import spawn; spawn(["echo", "ok"])' 2>/dev/null || log "WARN" "PTY support test failed, continuing anyway..."

# Patch for GCC 15
apply_patch "expect" "gcc15"

./configure --prefix=/usr           \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --disable-rpath         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include

make $MAKEFLAGS
make install
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib

cleanup
mark_built "$PKG_NAME"
