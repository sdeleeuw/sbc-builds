#!/bin/sh
set -e

NAME=Python
VERSION=3.12.8

# download sources
test -e ${NAME}-${VERSION}.tgz || \
  wget "https://www.python.org/ftp/python/${VERSION}/${NAME}-${VERSION}.tgz" \
    -O ${NAME}-${VERSION}.tgz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tgz

# setup
cd ${NAME}-${VERSION}
./configure \
  --prefix=/opt/python3.12 \
  --enable-optimizations \
  --enable-shared

# compile
make -j $(nproc)
