#!/bin/sh
set -e

NAME=dillo
GIT_REVISION=6a58684
VERSION=20251025-${GIT_REVISION}
ARCH=$(uname -m)

# clean up previous build
rm -rf "${NAME}-${VERSION}"

if [ -e "${NAME}-${VERSION}-git.tar.gz" ]; then

  # check integrity
  sha256sum -c checksums-sha256.txt

  # extract sources from tarball
  tar xf "${NAME}-${VERSION}-git.tar.gz"

else

  # download source from GitHub
  git clone --depth 1 \
    https://github.com/dillo-browser/dillo.git \
    "${NAME}-${VERSION}"

  # checkout specific commit
  ( cd "${NAME}-${VERSION}"
    git checkout ${GIT_REVISION}
  )

  # create source tarball
  tar cvzf "${NAME}-${VERSION}-git.tar.gz" "${NAME}-${VERSION}/"

  # save checksum
  sha256sum "${NAME}-${VERSION}-git.tar.gz" > checksums-sha256.txt

fi

# configure
cd "${NAME}-${VERSION}"
./autogen.sh
./configure --prefix=/opt/dillo

# compile
make -j $(nproc)

# install
sudo make install

# create binary package
( cd /
  tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/dillo
)

cd ..
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" .
