#!/bin/bash
LFS_VERSION="12.4"
# Core Toolchain
export BINUTILS_VERSION="2.45"
export GCC_VERSION="15.2.0"
export GLIBC_VERSION="2.42"
export LINUX_VERSION="6.16.1"
export MPFR_VERSION="4.2.2"
export GMP_VERSION="6.3.0"
export MPC_VERSION="1.3.1"

# Basic System Software
export M4_VERSION="1.4.20"
export NCURSES_VERSION="6.5"
export BASH_VERSION="5.3"
export COREUTILS_VERSION="9.7"
export DIFFUTILS_VERSION="3.11"
export FILE_VERSION="5.46"
export FINDUTILS_VERSION="4.10.0"
export GAWK_VERSION="5.3.1"
export GREP_VERSION="3.11"
export GZIP_VERSION="1.14"
export MAKE_VERSION="4.4.1"
export PATCH_VERSION="2.8"
export SED_VERSION="4.9"
export TAR_VERSION="1.35"
export XZ_VERSION="5.8.1"
export BZIP2_VERSION="1.0.8"
export ZLIB_VERSION="1.3.1"
export LZ4_VERSION="1.10.0"
export ZSTD_VERSION="1.5.7"
export READLINE_VERSION="8.3"
export BC_VERSION="1.08.1"
export FLEX_VERSION="2.6.4"
export TCL_VERSION="8.6.16"
export EXPECT_VERSION="5.45.4"
export DEJAGNU_VERSION="1.6.3"
export PKGCONF_VERSION="2.3.0"
export ATTR_VERSION="2.5.3"
export ACL_VERSION="2.3.3"
export LIBCAP_VERSION="2.76"
export LIBXCRYPT_VERSION="4.4.38"
export SHADOW_VERSION="4.17.3"
export PSMISC_VERSION="23.8"
export GETTEXT_VERSION="0.23.1"
export BISON_VERSION="3.8.2"
export LIBTOOL_VERSION="2.5.4"
export GDBM_VERSION="1.25"
export GPERF_VERSION="3.1"
export EXPAT_VERSION="2.7.1"
export INETUTILS_VERSION="2.6"
export LESS_VERSION="679"
export PERL_VERSION="5.41.3"
export XML_PARSER_VERSION="2.47"
export INTLTOOL_VERSION="0.51.0"
export AUTOCONF_VERSION="2.72"
export AUTOMAKE_VERSION="1.17"
export OPENSSL_VERSION="3.5.2"
export KMOD_VERSION="34.2"
export ELFUTILS_VERSION="0.193"
export LIBFFI_VERSION="3.5.2"
export PYTHON_VERSION="3.13.7"
export FLIT_CORE_VERSION="3.11.0"
export NINJA_VERSION="1.13.1"
export MESON_VERSION="1.8.3"
export CHECK_VERSION="0.15.2"
export GROFF_VERSION="1.23.0"
export GRUB_VERSION="2.12"
export IPROUTE2_VERSION="6.16.0"
export KBD_VERSION="2.8.0"
export LIBPIPELINE_VERSION="1.5.8"
export TEXINFO_VERSION="7.2"
export VIM_VERSION="9.1.1629"
export MARKUPSAFE_VERSION="3.0.2"
export JINJA2_VERSION="3.1.6"
export UDEV_VERSION="257.8"
export MAN_DB_VERSION="2.14.0"
export PROCPS_NG_VERSION="4.0.5"
export UTIL_LINUX_VERSION="2.41.1"
export E2FSPROGS_VERSION="1.47.2"
export SYSLOGD_VERSION="2.7.2"
export SYSVINIT_VERSION="3.14"
export BOOTSCRIPTS_VERSION="20250827"
export IANA_ETC_VERSION="20250807"

# Target directory for the LFS system
export LFS="/mnt/lfs"

# Chroot Detection: If we are inside the new system, LFS should be /
if [ -f /usr/bin/bash ] && [ ! -d /mnt/lfs ]; then
    export LFS=""
fi

# Target architecture triplet
export LFS_TGT="x86_64-lfs-linux-gnu"

# Path configuration
export PATH="$LFS/tools/bin:/usr/bin:/usr/sbin:/usr/local/bin"

# Parallel build settings - use all available cores
export MAKEFLAGS="-j$(nproc)"

# Workspace directories
export GINGER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export GINGER_SCRIPTS="$GINGER_ROOT/scripts"
export GINGER_SOURCES="$GINGER_ROOT/sources"
export GINGER_LOGS="$GINGER_ROOT/logs"

# Ensure directories exist
mkdir -p "$GINGER_SOURCES" "$GINGER_LOGS"

# Color codes for logging
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export NC='\033[0m' # No Color
