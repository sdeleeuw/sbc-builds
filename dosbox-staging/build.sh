#!/bin/sh
set -e

NAME=dosbox-staging
VERSION=0.83.0
ARCH=$(uname -m)

# bundled libraries (missing or too old in Debian)
FLUIDSYNTH_VERSION=2.5.7
IIR1_VERSION=1.10.0
MT32EMU_VERSION=2.7.3
ZLIB_NG_VERSION=2.3.3

FLUIDSYNTH_DIRNAME=fluidsynth-${FLUIDSYNTH_VERSION}
IIR1_DIRNAME=iir1-${IIR1_VERSION}
MT32EMU_TAG=libmt32emu_$(echo ${MT32EMU_VERSION} | tr . _)
MT32EMU_DIRNAME=munt-${MT32EMU_TAG}
ZLIB_NG_DIRNAME=zlib-ng-${ZLIB_NG_VERSION}

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/dosbox-staging/${NAME}/archive/refs/tags/v${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

test -e ${FLUIDSYNTH_DIRNAME}.tar.gz || \
  wget "https://github.com/FluidSynth/fluidsynth/archive/refs/tags/v${FLUIDSYNTH_VERSION}.tar.gz" \
    -O ${FLUIDSYNTH_DIRNAME}.tar.gz

test -e ${IIR1_DIRNAME}.tar.gz || \
  wget "https://github.com/berndporr/iir1/archive/refs/tags/${IIR1_VERSION}.tar.gz" \
    -O ${IIR1_DIRNAME}.tar.gz

test -e libmt32emu-${MT32EMU_VERSION}.tar.gz || \
  wget "https://github.com/munt/munt/archive/refs/tags/${MT32EMU_TAG}.tar.gz" \
    -O libmt32emu-${MT32EMU_VERSION}.tar.gz

test -e ${ZLIB_NG_DIRNAME}.tar.gz || \
  wget "https://github.com/zlib-ng/zlib-ng/archive/refs/tags/${ZLIB_NG_VERSION}.tar.gz" \
    -O ${ZLIB_NG_DIRNAME}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION} ${FLUIDSYNTH_DIRNAME} ${IIR1_DIRNAME} ${MT32EMU_DIRNAME} ${ZLIB_NG_DIRNAME}

# extract tarballs
tar xzf ${NAME}-${VERSION}.tar.gz
tar xzf ${FLUIDSYNTH_DIRNAME}.tar.gz
tar xzf ${IIR1_DIRNAME}.tar.gz
tar xzf libmt32emu-${MT32EMU_VERSION}.tar.gz
tar xzf ${ZLIB_NG_DIRNAME}.tar.gz

# --------

# FluidSynth (static, synthesizer only: DOSBox uses SDL for audio output)
( cd ${FLUIDSYNTH_DIRNAME}
  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -Dosal=cpp11 \
    -Denable-alsa=OFF \
    -Denable-dbus=OFF \
    -Denable-jack=OFF \
    -Denable-ladspa=OFF \
    -Denable-libinstpatch=OFF \
    -Denable-libsndfile=OFF \
    -Denable-midishare=OFF \
    -Denable-openmp=OFF \
    -Denable-oss=OFF \
    -Denable-pipewire=OFF \
    -Denable-pulseaudio=OFF \
    -Denable-readline=OFF \
    -Denable-sdl3=OFF \
    -Denable-systemd=OFF \
    -B build
  cmake --build build --parallel $(nproc)
  sudo cmake --install build
)

# --------

# iir1 (static, Debian's libiir-dev CMake config is broken)
( cd ${IIR1_DIRNAME}
  sed -i 's/add_library(iir SHARED/add_library(iir STATIC/' CMakeLists.txt
  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DIIR1_BUILD_DEMO=OFF \
    -DIIR1_BUILD_TESTING=OFF \
    -B build
  cmake --build build --parallel $(nproc)
  sudo cmake --install build
)

# --------

# libmt32emu (static)
( cd ${MT32EMU_DIRNAME}/mt32emu
  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -Dlibmt32emu_SHARED=OFF \
    -B build
  cmake --build build --parallel $(nproc)
  sudo cmake --install build
)

# --------

# zlib-ng (static)
( cd ${ZLIB_NG_DIRNAME}
  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTING=OFF \
    -B build
  cmake --build build --parallel $(nproc)
  sudo cmake --install build
)

# --------

cd ${NAME}-${VERSION}

# install the contents of the resources dir, not the dir itself (upstream bug,
# see https://github.com/dosbox-staging/dosbox-staging/pull/5046)
sed -i 's|/${RESOURCE_COPY_PATH}"|/${RESOURCE_COPY_PATH}/"|' \
  cmake/add_install_rules.cmake

# configure (using system libraries)
cmake \
  --preset=release-linux \
  --install-prefix=/opt/dosbox-staging \
  -DOPT_TESTS=OFF

# compile
cmake --build --preset=release-linux

# install
sudo cmake --install build/release-linux

# use full paths in the menu entry
sudo sed -i \
  -e 's|^Exec=dosbox$|Exec=/opt/dosbox-staging/bin/dosbox|' \
  -e 's|^Icon=org.dosbox_staging.dosbox_staging$|Icon=/opt/dosbox-staging/share/icons/hicolor/1024x1024/apps/org.dosbox_staging.dosbox_staging.png|' \
  /opt/dosbox-staging/share/applications/org.dosbox_staging.dosbox_staging.desktop

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/dosbox-staging )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../
