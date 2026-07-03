#!/bin/sh
set -e

DILLO_VERSION=3.3.0
DILLO_TARBALL=dillo-${DILLO_VERSION}.tar.gz
DILLO_DOWNLOAD_URL="https://dillo-browser.org/release/${DILLO_VERSION}/${DILLO_TARBALL}"

ARCH=$(uname -m)
INSTALL_PREFIX=/opt/dillo
PACKAGE_NAME=dillo-${DILLO_VERSION}-${ARCH}.tar.gz

# download sources

test -e ${DILLO_TARBALL} \
  || wget "${DILLO_DOWNLOAD_URL}"

# verify checksums

test -e checksums-sha256.txt \
  && sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf dillo-${DILLO_VERSION}
tar xf ${DILLO_TARBALL}

( cd dillo-${DILLO_VERSION}

  # configure
  ./configure \
    --prefix=${INSTALL_PREFIX}

  # compile
  make -j $(nproc)

  # install
  sudo make install
)

# create binary package

sudo mv ${INSTALL_PREFIX}/bin/dillo ${INSTALL_PREFIX}/bin/dillo.real
sudo cp ./dillo-wrapper.sh ${INSTALL_PREFIX}/bin/dillo
( cd /; tar cvzf /tmp/${PACKAGE_NAME} ${INSTALL_PREFIX} )
mv /tmp/${PACKAGE_NAME} ./
