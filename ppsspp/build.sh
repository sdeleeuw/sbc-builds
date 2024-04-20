#!/bin/sh
set -e

NAME=ppsspp
VERSION=1.17.1

# clean up previous build
rm -rf "${NAME}-${VERSION}"

if [ -e "${NAME}-${VERSION}-git.tar.gz" ]; then

  # check integrity
  sha256sum -c checksums-sha256.txt

  # extract sources from tarball
  tar xf "${NAME}-${VERSION}-git.tar.gz"

else

  # checkout sources from GitHub
  git clone \
    --branch "v${VERSION}" \
    --depth 1 \
    --recurse-submodules \
    https://github.com/hrydgard/ppsspp.git \
    "${NAME}-${VERSION}"

  # create source tarball
  tar cvzf "${NAME}-${VERSION}-git.tar.gz" "${NAME}-${VERSION}/"

  # save checksum
  sha256sum "${NAME}-${VERSION}-git.tar.gz" > checksums-sha256.txt

fi 

# configure
mkdir -p "${NAME}-${VERSION}/build"
cd "${NAME}-${VERSION}/build"

cmake --install-prefix=/opt/ppsspp ..

# compile
make -j $(nproc)
