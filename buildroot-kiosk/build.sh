#!/bin/bash
set -e -x

export BR2_DL_DIR=/build/downloads

# clean up previous build
test -d "buildroot" && \
rm -rf "buildroot"

# checkout buildroot source
git clone --depth 1 https://gitlab.com/buildroot.org/buildroot.git

# build
cd buildroot
make BR2_EXTERNAL=/build raspberrypizero2w_kiosk_defconfig
make BR2_EXTERNAL=/build
