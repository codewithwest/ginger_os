#!/bin/bash
# LFS 12.4 - 8.83. Sysklogd-2.7.2
source "/scripts/lib/common.sh"
PKG_NAME="sysklogd"
check_built "$PKG_NAME" && exit 0
extract "sysklogd"

./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --runstatedir=/run \
            --without-logger   \
            --disable-static   \
            --docdir=/usr/share/doc/sysklogd-2.7.2
            

make $MAKEFLAGS
make install

cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# Do not open any internet ports.
secure_mode 2

# End /etc/syslog.conf
EOF


cleanup
mark_built "$PKG_NAME"
# Note: Root required for syslog install.
