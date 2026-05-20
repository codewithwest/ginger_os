#!/bin/bash
source "/lfs/lib/common.sh"
PKG_NAME="perl-bridge"
check_built "$PKG_NAME" && exit 0
extract "perl"

sh Configure -des                                         \
             -D prefix=/usr                               \
             -D vendorprefix=/usr                         \
             -D useshrplib                                \
             -D privlib=/usr/lib/perl5/${PERL_VERSION}/core_perl     \
             -D archlib=/usr/lib/perl5/${PERL_VERSION}/core_perl     \
             -D sitelib=/usr/lib/perl5/${PERL_VERSION}/site_perl     \
             -D sitearch=/usr/lib/perl5/${PERL_VERSION}/site_perl    \
             -D vendorlib=/usr/lib/perl5/${PERL_VERSION}/vendor_perl \
             -D vendorarch=/usr/lib/perl5/${PERL_VERSION}/vendor_perl

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
