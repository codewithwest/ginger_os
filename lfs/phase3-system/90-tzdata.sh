#!/bin/bash
# LFS 13.0 - ${TZDATA_VERSION} - TZData (Placeholder)
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
PKG_NAME="tzdata-${TZDATA_VERSION}"
check_built "$PKG_NAME" && exit 0
extract "tzdata"

# TZData does not use a configure step; install the timezone data files directly
cd "tzdata-${TZDATA_VERSION}"
cp -v -R zoneinfo /usr/share/zoneinfo
cp -v leapseconds /usr/share/zoneinfo
cp -v tzdata.zi /usr/share/zoneinfo

cleanup
mark_built "$PKG_NAME"
