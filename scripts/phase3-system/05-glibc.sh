#!/bin/bash
# LFS 12.4 - 8.5. Glibc-2.42
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="glibc-final"
check_built "$PKG_NAME" && exit 0
extract "glibc"

# FHS patch (if present)
patch -Np1 -i ../glibc-2.42-fhs-1.patch

sed -e '/unistd.h/i #include <string.h>' \
    -e '/libc_rwlock_init/c\
  __libc_rwlock_define_initialized (, reset_lock);\
  memcpy (&lock, &reset_lock, sizeof (lock));' \
    -i stdlib/abort.c 

mkdir -v build
cd build

echo "rootsbindir=/usr/sbin" > configparms

../configure --prefix=/usr                   \
             --disable-werror                \
             --disable-nscd                  \
             libc_cv_slibdir=/usr/lib        \
             --enable-stack-protector=strong \
             --enable-kernel=5.4

make $MAKEFLAGS

# Optional: make check
# (Takes a long time, skipping for automation)


# Fix ldd path
touch /etc/ld.so.conf

sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile

make install

sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd

# Install configurations
mkdir -pv /etc/ld.so.conf.d
cat > /etc/ld.so.conf << "EOF"
/usr/local/lib
/opt/lib
include /etc/ld.so.conf.d/*.conf
EOF


cd ../.. && rm -rf "glibc-"*
mark_built "$PKG_NAME"
