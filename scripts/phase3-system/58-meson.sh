#!/bin/bash
# LFS 12.4 - 8.58. Meson-1.8.3
source "$(dirname "$(readlink -f "$0")")/common.sh"
PKG_NAME="meson"
check_built "$PKG_NAME" && exit 0
extract "meson"
python3 setup.py build
python3 setup.py install --root dest
cp -rv dest/* /
install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
cd .. && rm -rf "meson-"*
mark_built "$PKG_NAME"
# Note: meson uses setuptools which should be part of python install.
# If not, it uses a wheel. LFS 12.4 usually expects setuptools.
