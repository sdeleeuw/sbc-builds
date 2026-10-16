#!/bin/sh
set -e

NAME=thextech
VERSION=1.7.4
ARCH=$(uname -m)

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/TheXTech/TheXTech/releases/download/v${VERSION}/${NAME}-full-src-v${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz
mv thextech-full-src ${NAME}-${VERSION}

# don't install with RUNPATH "." (libraries would be loaded from the current
# directory); all libraries are either from Debian or linked static
sed -i 's/^set(CMAKE_INSTALL_RPATH ".")$/set(CMAKE_INSTALL_RPATH "")/' \
  ${NAME}-${VERSION}/CMakeLists.txt

# setup
mkdir ${NAME}-${VERSION}/build
cd ${NAME}-${VERSION}/build
cmake \
  -G Ninja \
  --install-prefix=/opt/thextech \
  -DCMAKE_BUILD_TYPE=MinSizeRel \
  -DUSE_SYSTEM_LIBS=OFF \
  -DUSE_SYSTEM_SDL2=ON \
  -DUSE_FREEIMAGE_SYSTEM_LIBS=ON \
  -DPGE_SHARED_SDLMIXER=OFF \
  ..

# compile
ninja

# install
sudo ninja install

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/thextech )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../../
