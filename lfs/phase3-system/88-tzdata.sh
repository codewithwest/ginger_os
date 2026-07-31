#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
PKG_NAME="tzdata"
check_built "$PKG_NAME" && exit 0

# tzdata has no top-level directory; install directly
tar -xf /sources/tzdata2025c.tar.gz

ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}

for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done

cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO tz

mark_built "$PKG_NAME"
