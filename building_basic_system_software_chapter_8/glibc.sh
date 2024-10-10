#!/bin/bash
echo "################################################################################";
echo "#--------------------------Setting LFS variable--------------------------------#";
echo "################################################################################";
echo;echo;echo;
# LFS=/mnt/lfs;
sleep 5;
# Extract package 
echo "################################################################################";
echo "#-------------------------Change into sources dir------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $LFS/sources;
pwd;
sleep 5;
# tar -xvf $LFS/sources/$(cd $LFS/sources/ &&  cat wget-list | grep glibc | grep tar);
echo "################################################################################";
echo "#----------------------------Extracting glibc package--------------------------#";
echo "################################################################################";
echo;echo;echo;
tar -xvf $(find "$LFS/sources" -type f | grep "$LFS/sources/glibc" | grep ".tar");
echo "################################################################################";
echo "#------------------------Extracting glibc archive complete---------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# change into the extracted package
echo "################################################################################";
echo "#-----------------------------Change into glibc dir----------------------------#";
echo "################################################################################";
echo;echo;echo;
cd $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/glibc");
pwd;
sleep 2;
# Some of the Glibc programs use the non-FHS compliant /var/db directory to store their 
# runtime data. Apply the following patch to make such programs store their runtime data 
# in the FHS-compliant locations:
echo "################################################################################";
echo "#----------------------------Apply glibc patch---------------------------------#";
echo "################################################################################";
echo;echo;echo;
patch -Np1 -i $(find "$LFS/sources" -type f | grep "$LFS/sources/glibc" | grep "patch");
sleep 2;
echo "################################################################################";
echo "#------------------------Apply glibc patch complete----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#----------------------------Create build dir----------------------------------#";
echo "################################################################################";
echo;echo;echo;
mkdir -v build;
sleep 2;
echo "################################################################################";
echo "#--------------------------Change into build dir-------------------------------#";
echo "################################################################################";
echo;echo;echo;
cd build;
sleep 2;
echo "################################################################################";
echo "#---Ensure that the ldconfig and sln utilities are installed into /usr/sbin----#";
echo "################################################################################";
echo;echo;echo;
echo "rootsbindir=/usr/sbin" > configparms;
echo "################################################################################";
echo "#------------------------------Configure tool----------------------------------#";
echo "################################################################################";
echo;echo;echo;
# Prepare package for compilation:
../configure --prefix=/usr                            \
             --disable-werror                         \
             --enable-kernel=4.19                     \
             --enable-stack-protector=strong          \
             --disable-nscd                           \
             libc_cv_slibdir=/usr/lib;
echo "################################################################################";
echo "#-------------------------Configure tool completed-----------------------------#";
echo "################################################################################";
echo;echo;echo;
echo "################################################################################";
echo "#------------------------------------Make tool---------------------------------#";
echo "################################################################################";
echo;echo;echo;
time make;
echo "################################################################################";
echo "#---------------------------Make tool complete---------------------------------#";
echo "################################################################################";
echo;echo;echo;
echo "################################################################################";
echo "#--------------------------------Test tool-------------------------------------#";
echo "################################################################################";
echo;echo;echo;
time make check;
echo "################################################################################";
echo "#---------------------------Test tool complete---------------------------------#";
echo "################################################################################";
echo;echo;echo;
# You may see some test failures. The Glibc test suite is somewhat dependent on the host 
# system. A few failures out of over 5000 tests can generally be ignored. This is a list 
# of the most common issues seen for recent versions of LFS:

# io/tst-lchmod is known to fail in the LFS chroot environment.

# Some tests, for example nss/tst-nss-files-hosts-multi and nptl/tst-thread-affinity* are 
# known to fail due to a timeout (especially when the system is relatively slow and/or 
# running the test suite with multiple parallel make jobs). These tests can be identified 
# with:

# grep "Timed out" $(find -name \*.out)
# It's possible to re-run a single test with enlarged timeout with TIMEOUTFACTOR=<factor> 
# make test t=<test name>. For example, TIMEOUTFACTOR=10 make test t=nss/tst-nss-files-hosts-multi 
# will re-run nss/tst-nss-files-hosts-multi with ten times the original timeout.

# Additionally, some tests may fail with a relatively old CPU model (for example elf/tst-cpu-features-cpuinfo)
# or host kernel version (for example stdlib/tst-arc4random-thread).

# Though it is a harmless message, the install stage of Glibc will complain about the absence 
# of /etc/ld.so.conf. Prevent this warning with:
echo "################################################################################";
echo "#----------------------------create /etc/ld.so.conf----------------------------#";
echo "################################################################################";
echo;echo;echo;
touch /etc/ld.so.conf;
sleep 2;
echo "################################################################################";
echo "#------------------------create /etc/ld.so.conf complete-----------------------#";
echo "################################################################################";
echo;echo;echo;
echo "################################################################################";
echo "#---------------Fix the Makefile to skip an outdated sanity -------------------#";
echo "#-------------check that fails with a modern Glibc configuration:--------------#";
echo "################################################################################";
echo;echo;echo;
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile;
sleep 2;
echo "################################################################################";
echo "#--------Fix the Makefile to skip an outdated sanity check complete------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#---------------------------------Install tool---------------------------------#";
echo "################################################################################";
echo;echo;echo;
make install;
echo "################################################################################";
echo "#------------------------------Install tool complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#----Fix a hardcoded path to the executable loader in the ldd script:----------#";
echo "################################################################################";
echo;echo;echo;
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
echo "################################################################################";
echo "#---Fix a hardcoded path to the executable loader in the ldd script complete---#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# Next, install the locales that can make the system respond in a different language. None 
# of these locales are required, but if some of them are missing, the test suites of some 
# packages will skip important test cases.

# Individual locales can be installed using the localedef program. E.g., the second 
# localedef command below combines the /usr/share/i18n/locales/cs_CZ charset-independent 
# locale definition with the /usr/share/i18n/charmaps/UTF-8.gz charmap definition and 
# appends the result to the /usr/lib/locale/locale-archive file. The following instructions 
# will install the minimum set of locales necessary for the optimal coverage of tests:
echo "################################################################################";
echo "#---------------------------- install the locales------------------------------#";
echo "################################################################################";
echo;echo;echo;
localedef -i C -f UTF-8 C.UTF-8;
localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8;
localedef -i de_DE -f ISO-8859-1 de_DE;
localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro;
localedef -i de_DE -f UTF-8 de_DE.UTF-8;
localedef -i el_GR -f ISO-8859-7 el_GR;
localedef -i en_GB -f ISO-8859-1 en_GB;
localedef -i en_GB -f UTF-8 en_GB.UTF-8;
localedef -i en_HK -f ISO-8859-1 en_HK;
localedef -i en_PH -f ISO-8859-1 en_PH;
localedef -i en_US -f ISO-8859-1 en_US;
localedef -i en_US -f UTF-8 en_US.UTF-8;
localedef -i es_ES -f ISO-8859-15 es_ES@euro;
localedef -i es_MX -f ISO-8859-1 es_MX;
localedef -i fa_IR -f UTF-8 fa_IR;
localedef -i fr_FR -f ISO-8859-1 fr_FR;
localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro;
localedef -i fr_FR -f UTF-8 fr_FR.UTF-8;
localedef -i is_IS -f ISO-8859-1 is_IS;
localedef -i is_IS -f UTF-8 is_IS.UTF-8;
localedef -i it_IT -f ISO-8859-1 it_IT;
localedef -i it_IT -f ISO-8859-15 it_IT@euro;
localedef -i it_IT -f UTF-8 it_IT.UTF-8;
localedef -i ja_JP -f EUC-JP ja_JP;
localedef -i ja_JP -f SHIFT_JIS ja_JP.SJIS 2> /dev/null || true;
localedef -i ja_JP -f UTF-8 ja_JP.UTF-8;
localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro;
localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R;
localedef -i ru_RU -f UTF-8 ru_RU.UTF-8;
localedef -i se_NO -f UTF-8 se_NO.UTF-8;
localedef -i ta_IN -f UTF-8 ta_IN.UTF-8;
localedef -i tr_TR -f UTF-8 tr_TR.UTF-8;
localedef -i zh_CN -f GB18030 zh_CN.GB18030;
localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS;
localedef -i zh_TW -f UTF-8 zh_TW.UTF-8;
sleep 1;
make localedata/install-locales;
echo "################################################################################";
echo "#-----------------------install the locales complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#------------------------8.5.2. Configuring Glibc------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#---------------------------Adding nsswitch.conf-------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# The /etc/nsswitch.conf file needs to be created because the Glibc defaults do not work 
# well in a networked environment.

# Create a new file /etc/nsswitch.conf by running the following:

cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files systemd
group: files systemd
shadow: files systemd

hosts: mymachines resolve [!UNAVAIL=return] files myhostname dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

echo "################################################################################";
echo "#-----------------------Adding nsswitch.conf complete--------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#--------------------------Adding Time Zone Data-------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# The /etc/nsswitch.conf file needs to be created because the Glibc defaults do not work 
# well in a networked environment.

# Create a new file /etc/nsswitch.conf by running the following:

tar -xf ../../tzdata2024a.tar.gz;

ZONEINFO=/usr/share/zoneinfo;
mkdir -pv $ZONEINFO/{posix,right};

for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done
sleep 2;
cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO;
sleep 1;
zic -d $ZONEINFO -p America/New_York;
sleep 1;
unset ZONEINFO;


# One way to determine the local time zone is to run the following script:

TIMEZONERESOLVED=$((
    #todo
) | tzselect)
# After answering a few questions about the location, the script will output the name of the 
# time zone (e.g., America/Edmonton). There are also some other possible time zones listed in 
# /usr/share/zoneinfo such as Canada/Eastern or EST5EDT that are not identified by the script 
# but can be used.

# Then create the /etc/localtime file by running:

ln -sfv /usr/share/zoneinfo/$TIMEZONERESOLVED /etc/localtime;

echo "################################################################################";
echo "#-----------------------Adding Time Zone Data complete-------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#-------------------Configuring the Dynamic Loader-----------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# By default, the dynamic loader (/lib/ld-linux.so.2) searches through /usr/lib for dynamic 
# libraries that are needed by programs as they are run. However, if there are libraries in 
# directories other than /usr/lib, these need to be added to the /etc/ld.so.conf file in 
# order for the dynamic loader to find them. Two directories that are commonly known to 
# contain additional libraries are /usr/local/lib and /opt/lib, so add those directories 
# to the dynamic loader's search path.
echo "################################################################################";
echo "#-------------------Create a new file /etc/ld.so.conf -------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF
echo "################################################################################";
echo "#---------------Create a new file /etc/ld.so.conf complete---------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
# If desired, the dynamic loader can also search a directory and include the contents of files 
# found there. Generally the files in this include directory are one line specifying the desired 
# library path. To add this capability run the following commands:
echo "################################################################################";
echo "#---------------Create a new file /etc/ld.so.conf complete---------------------#";
echo "################################################################################";
echo;echo;echo;
cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d;
echo "################################################################################";
echo "#--------------Configuring the Dynamic Loader complete-------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
echo "################################################################################";
echo "#------------------8.5.2. Configuring Glibc complete---------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
sleep 2;
echo "################################################################################";
echo "#----------------------------------Clean Up -----------------------------------#";
echo "################################################################################";
echo;echo;echo;
sleep 2;
cd $LFS/sources;
sleep 2;
rm -rf $(find "$LFS/sources" -type d | grep -m1 "$LFS/sources/glibc");
echo "################################################################################";
echo "#--------------------------Clean Up Complete-----------------------------------#";
echo "################################################################################";
echo;echo;echo;