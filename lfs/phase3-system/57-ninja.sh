#!/bin/bash
# LFS 13.0  - 8.57. Ninja-1.13.1
source "/lfs/lib/common.sh"
PKG_NAME="ninja"
check_built "$PKG_NAME" && exit 0
extract "ninja"

export NINJAJOBS=4

python3 configure.py --bootstrap --verbose

install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja

cleanup
mark_built "$PKG_NAME"
