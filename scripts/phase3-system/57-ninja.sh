#!/bin/bash
# LFS 12.4 - 8.57. Ninja-1.13.1
source "/scripts/common.sh"
PKG_NAME="ninja"
ARCHIVE="ninja-1.13.1.tar.gz"
DIR_NAME="ninja-1.13.1"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
python3 configure.py --bootstrap
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
