#!/bin/bash
# LFS 13.0  - 8.29. GCC-15.2.0 (Final)
source "/lfs/lib/common.sh"
PKG_NAME="gcc-final"
check_built "$PKG_NAME" && exit 0
extract "gcc"

# Fix libgomp compatibility for newer host toolchains: const qualifier
# in affinity-fmt.c is treated as an error under -Werror.
perl -pi -e "s/char \*q = strchr \(p \+ 1, '\}'\);/const char *q = strchr (p + 1, '}');/" libgomp/affinity-fmt.c

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
             --disable-libstdcxx-pch  \
             --with-system-zlib

# 3. Build & Install
make $MAKEFLAGS
make install

# 4. Post-Installation
chown -v -R root:root \
    /usr/lib/gcc/$(gcc -dumpmachine)/${GCC_VERSION}/include{,-fixed}

# Create required symlinks
ln -svfr /usr/bin/cpp /usr/lib
ln -sfv gcc.1 /usr/share/man/man1/cc.1
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/${GCC_VERSION}/liblto_plugin.so \
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

cd ../.. && cleanup
mark_built "$PKG_NAME"
