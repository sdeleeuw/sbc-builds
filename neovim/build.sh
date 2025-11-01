#!/bin/sh
set -e

NAME=neovim
VERSION=0.11.4
ARCH=$(uname -m)

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/neovim/${NAME}/archive/refs/tags/v${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz

# compile
cd ${NAME}-${VERSION}
make CMAKE_BUILD_TYPE=Release

# install
sudo make CMAKE_INSTALL_PREFIX=/opt/neovim install

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/neovim )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../
