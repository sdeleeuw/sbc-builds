#!/bin/sh
set -e

NAME=RetroArch
VERSION=1.22.2
ARCH=$(uname -m)

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/libretro/${NAME}/archive/refs/tags/v${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz

# configure (OpenGL ES instead of desktop GL, no X11)
cd ${NAME}-${VERSION}
./configure \
  --prefix=/opt/retroarch \
  --disable-qt \
  --disable-x11 \
  --enable-opengles \
  --enable-opengles3

# compile
make -j $(nproc)

# install
sudo make install

# use full paths in the menu entry (upstream only installs an SVG icon)
sudo sed -i \
  -e 's|^TryExec=retroarch$|TryExec=/opt/retroarch/bin/retroarch|' \
  -e 's|^Exec=retroarch |Exec=/opt/retroarch/bin/retroarch |' \
  -e 's|^Icon=com.libretro.RetroArch$|Icon=/opt/retroarch/share/pixmaps/com.libretro.RetroArch.svg|' \
  /opt/retroarch/share/applications/com.libretro.RetroArch.desktop

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/retroarch )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../
