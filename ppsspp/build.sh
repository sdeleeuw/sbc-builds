#!/bin/sh
set -e

NAME=ppsspp
VERSION=1.17.1

# clean up previous build
rm -rf "${NAME}-${VERSION}"

if [ -e "${NAME}-${VERSION}-git.tar.gz" ]; then

  # extract sources from tarball
  tar xf "${NAME}-${VERSION}-git.tar.gz"

else

  # checkout sources from GitHub
  git clone --branch "v${VERSION}" --depth 1 \
    https://github.com/hrydgard/ppsspp.git \
    "${NAME}-${VERSION}"

  # checkout submodules
  cd "${NAME}-${VERSION}"
  git submodule update --init --recursive

  # create source tarball
  cd ..
  tar cvzf "${NAME}-${VERSION}-git.tar.gz" "${NAME}-${VERSION}/"

fi 

# configure
cd "${NAME}-${VERSION}"
cmake .

# compile
make
