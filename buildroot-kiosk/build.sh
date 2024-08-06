#!/bin/bash
set -e -x

# clean up previous build
test -d "buildroot" && \
rm -rf "buildroot"

# checkout buildroot source
git clone --depth 1 git@gitlab.com:buildroot.org/buildroot.git

# re-use downloads folder
ln -sf downloads buildroot/dl

# copy configs
cp -rv configs buildroot/

# build
make raspberrypizero2w_defconfig
make
