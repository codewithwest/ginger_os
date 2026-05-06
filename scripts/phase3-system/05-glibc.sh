#!/bin/bash
# LFS 12.4 - 8.5. Glibc-2.42
source "/scripts/lib/common.sh"
PKG_NAME="glibc-final"
check_built "$PKG_NAME" && exit 0
extract "glibc"

# FHS patch (if present)
apply_patch "glibc" "fhs"

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

# LFS book step: disable the test-installation target which runs perl to link a
# test binary against the new glibc. Inside the chroot this causes a segfault due
# to dynamic linker version mismatch between the host perl and the freshly built glibc.
# Replacing $(PERL) with 'echo not running' skips the test without breaking make install.
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile

# Disable trap for the volatile installation phase to prevent shell segfaults
trap - ERR

make install
INSTALL_RES=$?

# Re-enable trap
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

if [ $INSTALL_RES -ne 0 ]; then
    log "ERROR" "glibc make install failed with code $INSTALL_RES"
    exit $INSTALL_RES
fi

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
