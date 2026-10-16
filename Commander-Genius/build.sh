#!/bin/sh
set -e

NAME=Commander-Genius
VERSION=3.6.4

PREFIX=/opt/commandergenius
ARCH=$(uname -m)

# download sources
test -e ${NAME}-v${VERSION}.tar.gz || \
  wget "https://gitlab.com/Dringgstein/Commander-Genius/-/archive/v${VERSION}/${NAME}-v${VERSION}.tar.gz" \
    -O ${NAME}-v${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-v${VERSION}

# extract tarball
tar xzf ${NAME}-v${VERSION}.tar.gz

# setup
cd ${NAME}-v${VERSION}
mkdir build && cd build
cmake .. \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DAPPDIR=${PREFIX}/bin \
  -DSHAREDIR=${PREFIX}/share \
  -DGAMES_SHAREDIR=${PREFIX}/share \
  -DDATADIR=${PREFIX}/share/commandergenius

# compile
make -j $(nproc)

# install
sudo make install

# use full paths in the menu entry (upstream installs the icons as cg.<size>.png,
# so "Icon=cg" wouldn't be found even with the icon dir in the theme path)
sudo sed -i \
  -e "s|^Exec=CGeniusExe\$|Exec=${PREFIX}/bin/CGeniusExe|" \
  -e "s|^Icon=cg\$|Icon=${PREFIX}/share/icons/hicolor/512x512/apps/cg.512.png|" \
  ${PREFIX}/share/applications/cgenius.desktop

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/commandergenius )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../../
