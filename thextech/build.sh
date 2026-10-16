#!/bin/sh
set -e

NAME=thextech
VERSION=1.7.4
ARCH=$(uname -m)

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/TheXTech/TheXTech/releases/download/v${VERSION}/${NAME}-full-src-v${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# download assets (Super Mario Bros. X game pack)
test -e ${NAME}-game-smbx-1.3-v${VERSION}.deb || \
  wget "https://github.com/TheXTech/TheXTech/releases/download/v${VERSION}/${NAME}-game-smbx-1.3-v${VERSION}.deb"

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION} ${NAME}-game-smbx-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz
mv thextech-full-src ${NAME}-${VERSION}

# extract assets package
dpkg-deb -x ${NAME}-game-smbx-1.3-v${VERSION}.deb ${NAME}-game-smbx-${VERSION}

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

# use full paths in the menu entry
sudo sed -i \
  -e 's|^Exec=thextech |Exec=/opt/thextech/bin/thextech |' \
  -e 's|^Icon=thextech$|Icon=/opt/thextech/share/icons/hicolor/512x512/apps/thextech.png|' \
  /opt/thextech/share/applications/thextech.desktop

# install assets package (assets, launcher, menu entry and icon), using full
# paths in the launcher and menu entry; the menu entry uses "@F" instead of the
# field code "%F", which would be passed literally as an argument
GAME=../../${NAME}-game-smbx-${VERSION}/usr
sudo cp -r ${GAME}/share /opt/thextech/
sudo cp ${GAME}/bin/thextech-smbx /opt/thextech/bin/
sudo sed -i 's|^thextech -c /usr/share/|/opt/thextech/bin/thextech -c /opt/thextech/share/|' \
  /opt/thextech/bin/thextech-smbx
sudo sed -i \
  -e 's|^Exec=thextech-smbx |Exec=/opt/thextech/bin/thextech-smbx |' \
  -e 's|^Icon=smbx13$|Icon=/opt/thextech/share/icons/hicolor/16x16/apps/smbx13.png|' \
  -e 's| @F$| %F|' \
  /opt/thextech/share/applications/thextech-smbx.desktop

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/thextech )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../../
