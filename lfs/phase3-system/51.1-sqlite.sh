#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
PKG_NAME="sqlite"
check_built "$PKG_NAME" && exit 0
extract "sqlite"

./configure --prefix=/usr     \
            --disable-static  \
            --enable-fts{4,5} \
            CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 \
                      -D SQLITE_ENABLE_UNLOCK_NOTIFY=1   \
                      -D SQLITE_ENABLE_DBSTAT_VTAB=1     \
                      -D SQLITE_SECURE_DELETE=1"

make LDFLAGS.rpath=""
make install

cleanup
mark_built "$PKG_NAME"
