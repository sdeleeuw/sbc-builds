#!/bin/sh
set -e

NAME=supertuxkart
VERSION=1.5
ARCH=$(uname -m)

# download sources (including the game assets)
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/supertuxkart/stk-code/releases/download/${VERSION}/SuperTuxKart-${VERSION}-src.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz
mv SuperTuxKart-${VERSION}-src ${NAME}-${VERSION}

# configure
# - OpenGL ES renderer (default on aarch64, explicit for x86_64 test builds)
# - no Vulkan renderer (needs shaderc) and no in-game recorder (libopenglrecorder
#   is not in Debian)
mkdir -p "${NAME}-${VERSION}/build"
cd "${NAME}-${VERSION}/build"

cmake \
  -DUSE_GLES2=ON \
  -DNO_SHADERC=ON \
  -DBUILD_RECORDER=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  --install-prefix=/opt/supertuxkart \
  ..

# compile
make -j $(nproc)

# install
sudo make install

# remove static libraries and headers of the bundled angelscript and wiiuse
# (only linked into the binary)
sudo rm -rf /opt/supertuxkart/include /opt/supertuxkart/lib

# use full paths in the menu entry
sudo sed -i \
  -e 's|^Exec=supertuxkart$|Exec=/opt/supertuxkart/bin/supertuxkart|' \
  -e 's|^Icon=supertuxkart$|Icon=/opt/supertuxkart/share/icons/hicolor/1024x1024/apps/supertuxkart.png|' \
  /opt/supertuxkart/share/applications/supertuxkart.desktop

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/supertuxkart )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../../
