#!/bin/sh
set -e

NAME=eduke32
VERSION=20250813-10626-126f35ca8

# download sources
test -e ${NAME}_src_${VERSION}.tar.xz || \
  wget "https://dukeworld.com/eduke32/synthesis/latest/${NAME}_src_${VERSION}.tar.xz" \
    -O ${NAME}_src_${VERSION}.tar.xz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}_${VERSION}

# extract tarball
tar xf ${NAME}_src_${VERSION}.tar.xz

# compile
cd ${NAME}_${VERSION}
make -j $(nproc)
