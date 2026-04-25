#!/bin/sh
set -e

NAME=UZDoom
VERSION=4.14.3
ARCH=$(uname -m)

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/UZDoom/${NAME}/archive/refs/tags/${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz

# --------

ZMUSIC_VERSION=1.3.0
ZMUSIC_DIRNAME=ZMusic-${ZMUSIC_VERSION}

test -e ${ZMUSIC_DIRNAME}.tar.gz || \
  wget "https://github.com/ZDoom/ZMusic/archive/refs/tags/${ZMUSIC_VERSION}.tar.gz" \
    -O ${ZMUSIC_DIRNAME}.tar.gz

rm -rf ${ZMUSIC_DIRNAME}
tar xzf ${ZMUSIC_DIRNAME}.tar.gz

mkdir ${ZMUSIC_DIRNAME}/build
( cd ${ZMUSIC_DIRNAME}/build
  cmake -DCMAKE_BUILD_TYPE=Release ..
  cmake --build . --parallel $(nproc)
  sudo make install
)

# --------

# setup
mkdir ${NAME}-${VERSION}/build
cd ${NAME}-${VERSION}/build

cmake \
  -DCMAKE_INSTALL_PREFIX=/opt/UZDoom \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -G Ninja \
  ..

# compile
cmake --build .

# install
sudo cmake --install .

# copy libs
sudo mkdir -p /opt/UZDoom/lib
sudo cp /usr/local/lib/libzmusic.so.1 /opt/UZDoom/lib/

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/UZDoom )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../../
