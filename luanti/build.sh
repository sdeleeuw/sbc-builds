#!/bin/sh
set -e

NAME=luanti
VERSION=5.15.1
ARCH=$(uname -m)

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/luanti-org/${NAME}/archive/refs/tags/${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz

# configure
mkdir -p "${NAME}-${VERSION}/build"
cd "${NAME}-${VERSION}/build"

cmake \
  -DBUILD_SERVER=TRUE \
  -DBUILD_CLIENT=TRUE \
  -DENABLE_GLES2=TRUE \
  -DRUN_IN_PLACE=FALSE \
  -DCMAKE_BUILD_TYPE=Release \
  --install-prefix=/opt/luanti \
  ..

# compile
make -j $(nproc)

# install
sudo make install

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/luanti )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../../
