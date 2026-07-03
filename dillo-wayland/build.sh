#!/bin/sh
set -e

DILLO_VERSION=3.3.0
DILLO_TARBALL=dillo-${DILLO_VERSION}.tar.gz
DILLO_DOWNLOAD_URL="https://dillo-browser.org/release/${DILLO_VERSION}/${DILLO_TARBALL}"

FLTK_VERSION=1.4.5
FLTK_TARBALL=fltk-${FLTK_VERSION}-source.tar.gz
FLTK_DOWNLOAD_URL="https://github.com/fltk/fltk/releases/download/release-${FLTK_VERSION}/${FLTK_TARBALL}"

ARCH=$(uname -m)
INSTALL_PREFIX=/opt/dillo-wayland
PACKAGE_NAME=dillo-wayland-${DILLO_VERSION}-${ARCH}.tar.gz

# download sources

test -e ${FLTK_TARBALL} \
  || wget "${FLTK_DOWNLOAD_URL}"

test -e ${DILLO_TARBALL} \
  || wget "${DILLO_DOWNLOAD_URL}"

# verify checksums

test -e checksums-sha256.txt \
  && sha256sum -c checksums-sha256.txt

# FLTK

rm -rf fltk-${FLTK_VERSION}
tar xf ${FLTK_TARBALL}

( cd fltk-${FLTK_VERSION}

  cmake . -B build \
    -DFLTK_BACKEND_X11=OFF \
    -DFLTK_BUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}

  cmake --build build -j $(nproc)

  sudo cmake --install build
)

# Dillo

rm -rf dillo-${DILLO_VERSION}
tar xf ${DILLO_TARBALL}

( cd dillo-${DILLO_VERSION}

  FLTK_CONFIG=${INSTALL_PREFIX}/bin/fltk-config \
  ./configure \
    --prefix=${INSTALL_PREFIX} \
    --enable-experimental-fltk \
    --disable-xembed

  make -j $(nproc)

  sudo make install
)

# create binary package

sudo mv ${INSTALL_PREFIX}/bin/dillo ${INSTALL_PREFIX}/bin/dillo.real
sudo cp ./dillo-wrapper.sh ${INSTALL_PREFIX}/bin/dillo
( cd /; tar cvzf /tmp/${PACKAGE_NAME} ${INSTALL_PREFIX} )
mv /tmp/${PACKAGE_NAME} ./
