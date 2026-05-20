#!/bin/bash
# LFS 13.0 - 5.5. Glibc-2.43
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

PKG_NAME="glibc"
check_built "$PKG_NAME" && exit 0

extract "glibc"

log "PROCESS" "Compiling Glibc..."

# Create compatibility symlink
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
esac

patch -Np1 -i "$GINGER_SOURCES/glibc-fhs-1.patch"

mkdir -v build
cd build

echo "rootsbindir=/usr/sbin" > configparms

../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../lfsconfig.guess) \
      --disable-nscd                     \
      libc_cv_slibdir=/usr/lib           \
      --enable-kernel=5.4


make $MAKEFLAGS
make DESTDIR=$LFS install

sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd


# Fix ldd path
echo 'int main(){}' | $LFS_TGT-gcc -x c - -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep ': /lib'

grep -E -o "$LFS/lib.*/S?crt[1in].*succeeded" dummy.log

# Verify that the compiler is searching for the correct header files:
grep -B3 "^ $LFS/usr/include" dummy.log

grep "/lib.*/libc.so.6 " dummy.log

grep found dummy.log

rm -v a.out dummy.log

cd ../..
cleanup

mark_built "$PKG_NAME"
