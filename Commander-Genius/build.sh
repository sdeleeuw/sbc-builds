#!/bin/sh
set -e

NAME=Commander-Genius
VERSION=3.5.2

PREFIX=/opt/commandergenius
ARCH=$(uname -m)
DATE=$(date +%Y%m%d)

# download sources
test -e ${NAME}-v${VERSION}.tar.gz || \
  wget "https://gitlab.com/Dringgstein/Commander-Genius/-/archive/v3.5.2/Commander-Genius-v${VERSION}.tar.gz" \
    -O ${NAME}-v${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-v${VERSION}

# extract tarball
tar xzf ${NAME}-v${VERSION}.tar.gz

# apply source patches
cd ${NAME}-v${VERSION}
cat $(find ../patches/ -type f -name '*.patch' | sort) | patch -p1

# setup
mkdir build && cd build
cmake .. \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DAPPDIR=${PREFIX}/bin \
  -DSHAREDIR=${PREFIX}/share \
  -DGAMES_SHAREDIR=${PREFIX}/share \
  -DDATADIR=${PREFIX}/share/commandergenius

# compile
make -j $(nproc)

# install
sudo make install

# create binary tarball
cd /opt
tar cvzf /build/${NAME}-${VERSION}-${ARCH}-${DATE}.tar.gz commandergenius
