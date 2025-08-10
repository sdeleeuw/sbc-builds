#!/bin/sh
set -e

NAME=thextech
VERSION=1.3.7.1

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://wohlsoft.ru/projects/TheXTech/_downloads/releases/${NAME}-full-src-v${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz
mv thextech-full-src ${NAME}-${VERSION}


# setup
mkdir ${NAME}-${VERSION}/build
cd ${NAME}-${VERSION}/build
cmake \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=MinSizeRel \
  -DUSE_SYSTEM_LIBS=OFF \
  -DUSE_SYSTEM_SDL2=ON \
  -DUSE_FREEIMAGE_SYSTEM_LIBS=ON \
  -DPGE_SHARED_SDLMIXER=OFF \
  ..

# compile
ninja
