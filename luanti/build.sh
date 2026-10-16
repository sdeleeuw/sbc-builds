#!/bin/sh
set -e

NAME=luanti
VERSION=5.17.0
ARCH=$(uname -m)

MINECLONIA_VERSION=0.124.0
MINECLONIA_RELEASE=39338

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/luanti-org/${NAME}/archive/refs/tags/${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# download Mineclonia game (ContentDB release id ${MINECLONIA_RELEASE})
test -e mineclonia-${MINECLONIA_VERSION}.zip || \
  wget "https://content.luanti.org/packages/ryvnf/mineclonia/releases/${MINECLONIA_RELEASE}/download/" \
    -O mineclonia-${MINECLONIA_VERSION}.zip

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

# use full paths in the menu entry
sudo sed -i \
  -e 's|^Exec=luanti$|Exec=/opt/luanti/bin/luanti|' \
  -e 's|^Icon=luanti$|Icon=/opt/luanti/share/icons/hicolor/128x128/apps/luanti.png|' \
  /opt/luanti/share/applications/org.luanti.luanti.desktop

# install Mineclonia game
sudo rm -rf /opt/luanti/share/luanti/games/mineclonia
sudo unzip -q ../../mineclonia-${MINECLONIA_VERSION}.zip -d /opt/luanti/share/luanti/games

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/luanti )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../../
