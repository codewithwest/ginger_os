#!/bin/bash
# LFS 12.4 - 8.43. Perl-5.42.0
source "/scripts/common.sh"
PKG_NAME="perl"
ARCHIVE="perl-5.42.0.tar.xz"
DIR_NAME="perl-5.42.0"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
export BUILD_ZLIB=False
export BUILD_BZIP2=0
sh Configure -des                                         \
             -D prefix=/usr                               \
             -D vendorprefix=/usr                         \
             -D privlib=/usr/lib/perl5/5.42/core_perl      \
             -D archlib=/usr/lib/perl5/5.42/core_perl      \
             -D sitelib=/usr/lib/perl5/5.42/site_perl      \
             -D sitearch=/usr/lib/perl5/5.42/site_perl      \
             -D vendorlib=/usr/lib/perl5/5.42/vendor_perl  \
             -D vendorarch=/usr/lib/perl5/5.42/vendor_perl  \
             -D man1dir=/usr/share/man/man1               \
             -D man3dir=/usr/share/man/man3               \
             -D pager="/usr/bin/less -isR"                \
             -D useshrplib                                \
             -D usethreads
make $MAKEFLAGS
make install
unset BUILD_ZLIB BUILD_BZIP2
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
