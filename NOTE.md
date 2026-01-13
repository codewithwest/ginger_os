# Files executed in order:

1. disk-image-setup.sh (root, once)
2. download.sh (any user)
3. host-setup.sh (root)
4. sudo apt update
5. sudo apt install -y \
    build-essential bison gawk m4 texinfo \
    libncurses5-dev libtool autoconf automake \
    patch wget curl xz-utils bzip2 \
    file bc flex zlib1g-dev
6. host-requirements-install.sh (any user)
7. update-dir.sh (root)
8. su - lfs
9. setup-ls-user-env
10. Begin LFS Chapter 5 (temporary toolchain)