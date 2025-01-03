#!/bin/sh
set -e

NAME=RetroArch
VERSION=1.20.0

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/libretro/${NAME}/archive/refs/tags/v${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz

# configure
cd ${NAME}-${VERSION}
./configure --prefix=/opt/retroarch --disable-qt

# compile
make -j $(nproc)
