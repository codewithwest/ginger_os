#!/bin/bash
# LFS 13.0 - ${SQLITE_VERSION} - SQLite (Placeholder)
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
PKG_NAME="sqlite-autoconf-${SQLITE_VERSION}"
check_built "$PKG_NAME" && exit 0
extract "sqlite"

cd "sqlite-autoconf-${SQLITE_VERSION}"
./configure --prefix=/usr     \
            --disable-static  \
            --enable-fts{4,5} \
            CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 \
                      -D SQLITE_ENABLE_UNLOCK_NOTIFY=1   \
                      -D SQLITE_ENABLE_DBSTAT_VTAB=1     \
                      -D SQLITE_SECURE_DELETE=1"

make LDFLAGS.rpath="" ${MAKEFLAGS}
make install

cleanup
mark_built "$PKG_NAME"
