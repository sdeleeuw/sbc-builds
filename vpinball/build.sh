#!/bin/sh
set -e

NAME=vpinball
VERSION=10.8.1-5436-af26b2d93
ARCH=$(uname -m)

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/vpinball/${NAME}/archive/refs/tags/v${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz
cd ${NAME}-${VERSION}

# set revision and commit (normally done by upstream CI)
sed -i \
  -e "s/9999/$(echo ${VERSION} | cut -d- -f2)/" \
  -e "s/unknown/$(echo ${VERSION} | cut -d- -f3)/" \
  src/core/git_version.h

# build external libraries (SDL3, FreeImage, PinMAME, FFmpeg, ...)
./platforms/linux-aarch64/external.sh

# configure (OpenGL ES renderer)
cmake \
  -DRENDERER=GL \
  -DBUILD_RPI=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -B build

# compile
cmake --build build -- -j $(nproc)

# install
sudo mkdir -p /opt/vpinball
sudo cp build/VPinballX_GL /opt/vpinball/
sudo cp -a build/*.so build/*.so.* /opt/vpinball/
sudo cp -r build/shaders-* build/assets build/plugins build/scripts build/docs /opt/vpinball/

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/vpinball )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../
