#!/bin/bash
# LFS 12.4 - 8.29. GCC-15.2.0 (Final)
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="gcc-final"
check_built "$PKG_NAME" && exit 0
extract "gcc"

# 1. Prepare GCC
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

mkdir -v build
cd build

# 2. Configure
../configure --prefix=/usr            \
             LD=ld                    \
             --enable-languages=c,c++ \
             --enable-default-pie     \
             --enable-default-ssp     \
             --enable-host-pie        \
             --disable-multilib       \
             --disable-bootstrap      \
             --disable-fixincludes    \
             --with-system-zlib

# 3. Build & Install
make $MAKEFLAGS
make install

# 4. Post-Installation
chown -v -R root:root \
    /usr/lib/gcc/$(gcc -dumpmachine)/15.2.0/include{,-fixed}

# Create required symlinks
ln -svr /usr/bin/cpp /usr/lib
ln -sv gcc.1 /usr/share/man/man1/cc.1
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/15.2.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/

# 5. Sanity Checks (Crunch Time)
log "INFO" "Performing GCC sanity checks..."

echo 'int main(){}' | cc -x c - -v -Wl,--verbose &> dummy.log
if ! readelf -l a.out | grep ': /lib' | grep -q 'ld-linux-x86-64.so.2'; then
    log "ERROR" "GCC Sanity Check failed: Dynamic linker path is incorrect!"
    exit 1
fi

if ! grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log | grep -q 'succeeded'; then
    log "ERROR" "GCC Sanity Check failed: crt*.o files not found in /usr/lib!"
    exit 1
fi

if ! grep -B4 '^ /usr/include' dummy.log | grep -q 'starts here'; then
    log "ERROR" "GCC Sanity Check failed: include search paths are incorrect!"
    exit 1
fi

if ! grep 'SEARCH.*/usr/lib' dummy.log | sed 's|; |\n|g' | grep -q 'SEARCH_DIR("/usr/lib")'; then
    log "ERROR" "GCC Sanity Check failed: Search paths don't include /usr/lib!"
    exit 1
fi

if ! grep "/lib.*/libc.so.6 " dummy.log | grep -q 'succeeded'; then
    log "ERROR" "GCC Sanity Check failed: libc.so.6 not found or path incorrect!"
    exit 1
fi

if ! grep found dummy.log | grep -q "found ld-linux-x86-64.so.2 at /usr/lib/ld-linux-x86-64.so.2"; then
    log "ERROR" "GCC Sanity Check failed: Dynamic linker not found in /usr/lib!"
    exit 1
fi

log "INFO" "GCC Sanity Checks PASSED."
rm -v a.out dummy.log

# 6. Final cleanup & misplaced files
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib

cd ../.. && rm -rf "gcc-"*
mark_built "$PKG_NAME"
