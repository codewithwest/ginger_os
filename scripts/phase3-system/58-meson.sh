#!/bin/bash
# LFS 12.4 - 8.58. Meson-1.8.3
source "/scripts/common.sh"
PKG_NAME="meson"
ARCHIVE="meson-1.8.3.tar.gz"
DIR_NAME="meson-1.8.3"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
pip3 wheel -w dist --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist meson
install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
