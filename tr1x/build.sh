#!/bin/sh
set -e

NAME=tr1x
VERSION=4.13.2

# download sources
test -e tr1-${VERSION}.tar.gz || \
  wget "https://github.com/LostArtefacts/TRX/archive/refs/tags/tr1-${VERSION}.tar.gz" \
    -O tr1-${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf TRX-tr1-${VERSION}

# extract tarball
tar xf tr1-${VERSION}.tar.gz

# setup
cd TRX-tr1-${VERSION}/src/tr1
meson setup build/ \
  -Dprefix=/opt/tr1x \
  -Dstaticdeps=false

# compile
meson compile -C build/
