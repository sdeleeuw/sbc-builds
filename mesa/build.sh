#!/bin/sh
set -e

NAME=mesa
VERSION=25.2.0

# download sources
test -e ${NAME}-${VERSION}.tar.xz || \
  wget "https://archive.mesa3d.org/${NAME}-${VERSION}.tar.xz" \
    -O ${NAME}-${VERSION}.tar.xz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xf ${NAME}-${VERSION}.tar.xz

# setup
cd ${NAME}-${VERSION}
meson setup build/ --prefix=/opt/${NAME}-${VERSION}

# compile
meson compile -C build/
