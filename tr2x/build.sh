#!/bin/sh
set -e

NAME=tr2x
VERSION=1.3.2

# download sources
test -e tr2-${VERSION}.tar.gz || \
  wget "https://github.com/LostArtefacts/TRX/archive/refs/tags/tr2-${VERSION}.tar.gz" \
    -O tr2-${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf TRX-tr2-${VERSION}

# extract tarball
tar xf tr2-${VERSION}.tar.gz

# setup
cd TRX-tr2-${VERSION}/src/tr2
meson setup build/ \
  -Dprefix=/opt/tr2x \
  -Dstaticdeps=false

# compile
meson compile -C build/
