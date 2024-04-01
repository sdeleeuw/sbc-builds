#!/bin/sh
set -e

NAME=dosbox-staging
VERSION=0.81.0

CCACHE_COMPRESS=true
CCACHE_COMPRESSLEVEL=6
CCACHE_SLOPPINESS="pch_defines,time_macros"

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/dosbox-staging/${NAME}/archive/refs/tags/v${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

test -e "iir_1.9.3.tar.gz" || \
  wget "https://github.com/berndporr/iir1/archive/refs/tags/1.9.3.tar.gz" \
    -O "iir_1.9.3.tar.gz"

test -e "iir_1.9.3-1_patch.zip" || \
  wget "https://wrapdb.mesonbuild.com/v2/iir_1.9.3-1/get_patch" \
    -O "iir_1.9.3-1_patch.zip"

test -e "libmt32emu_2_7_1.tar.gz" || \
  wget "https://github.com/munt/munt/archive/libmt32emu_2_7_1.tar.gz" \
    -O "libmt32emu_2_7_1.tar.gz"

test -e "mt32emu_2.7.1-1_patch.zip" || \
  wget "https://wrapdb.mesonbuild.com/v2/mt32emu_2.7.1-1/get_patch" \
    -O "mt32emu_2.7.1-1_patch.zip"

# check integrity
sha256sum -c CHECKSUM.SHA256

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz

# copy subprojects
cd ${NAME}-${VERSION}
mkdir subprojects/packagecache
cp "../iir_1.9.3.tar.gz" "subprojects/packagecache/1.9.3.tar.gz"
cp "../iir_1.9.3-1_patch.zip" "subprojects/packagecache/"
cp "../libmt32emu_2_7_1.tar.gz" "subprojects/packagecache/"
cp "../mt32emu_2.7.1-1_patch.zip" "subprojects/packagecache/"

# setup
meson setup build/release --prefix=/opt/dosbox-staging

# compile
meson compile -C build/release
