#!/bin/sh
set -e

NAME=vkQuake
VERSION=1.37.0
ARCH=$(uname -m)

# bundled libraries (too old in Debian: vkQuake needs Vulkan >= 1.4.341 and
# spirv-opt with --canonicalize-ids), all from the same Vulkan SDK release
VULKAN_SDK_VERSION=1.4.341.0
VULKAN_SDK_TAG=vulkan-sdk-${VULKAN_SDK_VERSION}

SPIRV_HEADERS_DIRNAME=SPIRV-Headers-${VULKAN_SDK_TAG}
SPIRV_TOOLS_DIRNAME=SPIRV-Tools-${VULKAN_SDK_TAG}
VULKAN_HEADERS_DIRNAME=Vulkan-Headers-${VULKAN_SDK_TAG}
VULKAN_LOADER_DIRNAME=Vulkan-Loader-${VULKAN_SDK_TAG}

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/Novum/vkQuake/archive/refs/tags/${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

for LIB in SPIRV-Headers SPIRV-Tools Vulkan-Headers Vulkan-Loader; do
  test -e ${LIB}-${VULKAN_SDK_VERSION}.tar.gz || \
    wget "https://github.com/KhronosGroup/${LIB}/archive/refs/tags/${VULKAN_SDK_TAG}.tar.gz" \
      -O ${LIB}-${VULKAN_SDK_VERSION}.tar.gz
done

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION} ${SPIRV_HEADERS_DIRNAME} ${SPIRV_TOOLS_DIRNAME} \
  ${VULKAN_HEADERS_DIRNAME} ${VULKAN_LOADER_DIRNAME}

# extract tarballs
tar xzf ${NAME}-${VERSION}.tar.gz
for LIB in SPIRV-Headers SPIRV-Tools Vulkan-Headers Vulkan-Loader; do
  tar xzf ${LIB}-${VULKAN_SDK_VERSION}.tar.gz
done

# --------

# SPIRV-Headers (header only, needed by SPIRV-Tools)
( cd ${SPIRV_HEADERS_DIRNAME}
  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DSPIRV_HEADERS_ENABLE_TESTS=OFF \
    -B build
  sudo cmake --install build
)

# --------

# SPIRV-Tools (static, only spirv-opt is used to optimize the shaders)
( cd ${SPIRV_TOOLS_DIRNAME}
  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DSPIRV-Headers_SOURCE_DIR=/usr/local \
    -DSPIRV_SKIP_TESTS=ON \
    -DSPIRV_WERROR=OFF \
    -B build
  cmake --build build --parallel $(nproc)
  sudo cmake --install build
)

# --------

# Vulkan-Headers (header only)
( cd ${VULKAN_HEADERS_DIRNAME}
  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -B build
  sudo cmake --install build
)

# --------

# Vulkan-Loader (for linking only: at runtime vkQuake uses Debian's
# libvulkan.so.1, so the window system integration is not needed here)
( cd ${VULKAN_LOADER_DIRNAME}
  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_WSI_WAYLAND_SUPPORT=OFF \
    -DBUILD_WSI_XCB_SUPPORT=OFF \
    -DBUILD_WSI_XLIB_SUPPORT=OFF \
    -B build
  cmake --build build --parallel $(nproc)
  sudo cmake --install build
)

# --------

# setup
cd ${NAME}-${VERSION}
meson setup build/ --prefix=/opt/vkQuake -Duse_sdl3=disabled

# compile
meson compile -C build/

# install (upstream has no install rules; without the RUNPATH to the bundled
# loader in /usr/local, Debian's libvulkan.so.1 is used at runtime)
sudo mkdir -p /opt/vkQuake/bin
sudo cp build/vkquake /opt/vkQuake/bin/
sudo patchelf --remove-rpath /opt/vkQuake/bin/vkquake

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/vkQuake )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../
