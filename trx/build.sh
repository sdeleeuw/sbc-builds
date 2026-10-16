#!/bin/sh
set -e

NAME=trx
VERSION=1.11.1
ARCH=$(uname -m)

# shipped assets of the combined release (not part of the source tarball,
# see tools/download_assets)
ASSETS="tr1 tr1-ub tr1-demo-pc tr2 tr2-gm tr3 tr3-la tr4"

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/LostArtefacts/TRX/archive/refs/tags/${NAME}-${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

for ASSET in ${ASSETS}; do
  test -e ${NAME}-${VERSION}-assets-${ASSET}.zip || \
    wget "https://lostartefacts.dev/aux/trx/${ASSET}.zip" \
      -O ${NAME}-${VERSION}-assets-${ASSET}.zip
done

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf TRX-${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz

# extract assets
for ASSET in ${ASSETS}; do
  unzip -q -o ${NAME}-${VERSION}-assets-${ASSET}.zip -d TRX-${NAME}-${VERSION}/data/trx/ship
done

# configure
cd TRX-${NAME}-${VERSION}
meson setup build/trx src/ \
  --buildtype=release \
  --prefix=/opt/trx \
  --bindir=. \
  -Dstaticdeps=false \
  -Dtrx_version=${VERSION}

# compile
meson compile -C build/trx

# install
sudo meson install -C build/trx
sudo cp -r data/trx/ship/. /opt/trx/

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/trx )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../
