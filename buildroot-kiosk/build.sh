#!/bin/bash
set -e -x

export BR2_DL_DIR=/build/downloads

# clean up previous build
test -d "buildroot" && \
rm -rf "buildroot"

# checkout buildroot source
git clone --depth 1 https://gitlab.com/buildroot.org/buildroot.git

# copy configs
cp -rv configs buildroot/

# build
cd buildroot
make raspberrypizero2w_defconfig
make
