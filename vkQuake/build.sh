#!/bin/sh
set -e

NAME=vkQuake
VERSION=1.32.3.1

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/Novum/vkQuake/archive/refs/tags/${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz

# setup
cd ${NAME}-${VERSION}
meson setup build/ --prefix=/opt/vkQuake

# compile
meson compile -C build/
