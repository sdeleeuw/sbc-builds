#!/bin/sh
set -e

NAME=dolphin
VERSION=2506a

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
    --branch "${VERSION}" \
    --depth 1 \
    https://github.com/dolphin-emu/dolphin.git \
    "${NAME}-${VERSION}"

  # add submodules
  ( cd "${NAME}-${VERSION}"

    git -c submodule."Externals/Qt".update=none \
	-c submodule."Externals/FFmpeg-bin".update=none \
	-c submodule."Externals/libadrenotools".update=none \
	submodule update --init --recursive

    git pull --recurse-submodules
  )

  # create source tarball
  tar cvzf "${NAME}-${VERSION}-git.tar.gz" "${NAME}-${VERSION}/"

  # save checksum
  sha256sum "${NAME}-${VERSION}-git.tar.gz" > checksums-sha256.txt

fi

# configure
mkdir -p "${NAME}-${VERSION}/build"
cd "${NAME}-${VERSION}/build"

cmake --install-prefix=/home/sander/Applications/dolphin ..

# compile
make -j $(nproc)
