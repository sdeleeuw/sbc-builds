#!/bin/sh
set -e

NAME=dosbox-staging
VERSION=0.82.2

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/dosbox-staging/${NAME}/archive/refs/tags/v${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz

# setup
cd ${NAME}-${VERSION}
meson setup build/release --prefix=/opt/dosbox-staging

# compile
meson compile -C build/release
