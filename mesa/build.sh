#!/bin/sh
set -e

NAME=mesa
VERSION=25.2.1

# download sources
test -e ${NAME}-${VERSION}.tar.xz || \
  wget "https://archive.mesa3d.org/${NAME}-${VERSION}.tar.xz" \
    -O ${NAME}-${VERSION}.tar.xz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xf ${NAME}-${VERSION}.tar.xz

# setup
cd ${NAME}-${VERSION}
meson setup build/ \
  -Dprefix=/opt/${NAME}-${VERSION} \
  -Dplatforms=x11,wayland \
  -Dgallium-drivers=panfrost,zink \
  -Dvulkan-drivers=panfrost

# compile
meson compile -C build/
