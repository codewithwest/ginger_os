#!/bin/bash
# LFS 12.4 - 8.58. Meson-1.8.3
source "/scripts/lib/common.sh"
PKG_NAME="meson"
check_built "$PKG_NAME" && exit 0
extract "meson"


pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

pip3 install --no-index --find-links dist meson
install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson

cleanup
mark_built "$PKG_NAME"
# Note: meson uses setuptools which should be part of python install.
# If not, it uses a wheel. LFS 12.4 usually expects setuptools.
