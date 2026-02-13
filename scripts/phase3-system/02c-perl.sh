#!/bin/bash
# LFS 12.4 - 7.9. Perl-5.41.3 (Temporary)
source "/scripts/lib/common.sh"
PKG_NAME="perl-bridge"
check_built "$PKG_NAME" && exit 0
extract "perl"

sh Configure -des                                         \
             -D prefix=/usr                               \
             -D vendorprefix=/usr                         \
             -D useshrplib                                \
             -D privlib=/usr/lib/perl5/5.42/core_perl     \
             -D archlib=/usr/lib/perl5/5.42/core_perl     \
             -D sitelib=/usr/lib/perl5/5.42/site_perl     \
             -D sitearch=/usr/lib/perl5/5.42/site_perl    \
             -D vendorlib=/usr/lib/perl5/5.42/vendor_perl \
             -D vendorarch=/usr/lib/perl5/5.42/vendor_perl

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
