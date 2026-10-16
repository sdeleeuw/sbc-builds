#!/bin/sh
set -e

NAME=UZDoom
VERSION=5.0.3
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

# setup
mkdir ${NAME}-${VERSION}/build
cd ${NAME}-${VERSION}/build

# SHARE_DIR defaults to /usr/share, set it to the install prefix so the
# engine finds uzdoom.pk3 and the other resources in /opt/UZDoom/share
cmake \
  -DCMAKE_INSTALL_PREFIX=/opt/UZDoom \
  -DCMAKE_CXX_FLAGS='-DSHARE_DIR=\"/opt/UZDoom/share\"' \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -G Ninja \
  ..

# compile (the tarball has no git info, pass the version for gitinfo.h)
GIT_DESCRIBE=${VERSION} cmake --build .

# install
sudo cmake --install .

# use full paths in the menu entry and its actions (upstream only installs an
# SVG icon)
sudo sed -i \
  -e 's|^Exec=uzdoom |Exec=/opt/UZDoom/bin/uzdoom |' \
  -e 's|^Icon=org.zdoom.UZDoom$|Icon=/opt/UZDoom/share/icons/hicolor/scalable/apps/org.zdoom.UZDoom.svg|' \
  /opt/UZDoom/share/applications/org.zdoom.UZDoom.desktop

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/UZDoom )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../../
