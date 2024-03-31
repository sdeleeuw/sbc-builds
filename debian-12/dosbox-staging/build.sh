#!/bin/sh
set -e

NAME=dosbox-staging
VERSION=0.81.0

CCACHE_COMPRESS=true
CCACHE_COMPRESSLEVEL=6
CCACHE_SLOPPINESS="pch_defines,time_macros"

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/dosbox-staging/${NAME}/archive/refs/tags/v${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# check integrity
sha256sum -c ${NAME}-${VERSION}.tar.gz.sha256

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz

# setup
cd ${NAME}-${VERSION}
meson setup build/release

# compile
meson compile -C build/release
