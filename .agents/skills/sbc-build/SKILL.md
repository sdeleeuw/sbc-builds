---
name: sbc-build
description: Conventions and workflow for adding or bumping a package in the sbc-builds repo (Docker-based source builds of software for Raspberry Pi and other aarch64 single board computers). Use when creating a new package directory, bumping a version, adjusting a Dockerfile.debian-13 / build.sh / env.sh, or test-building for arm64.
---

# sbc-builds: adding and maintaining packages

Each top-level directory builds one piece of software from source for a Raspberry Pi
or another aarch64 SBC. The build happens inside a Debian 13 (Trixie) Docker image:
the **Dockerfile** only holds the apt dependencies, the **build.sh** holds the whole
build process. Consistency between packages matters a lot: before writing anything,
read 2–3 recent packages (`git log` shows the newest) and copy their exact format.

Good references: `luanti/` (cmake, tarball), `UZDoom/` (tarball + bundled extra lib),
`dillo-wayland/` (two sources, wayland), `dolphin/` and `ppsspp/` (git clone variant),
`vpinball/` (upstream external-deps script, GLES).

## Files per package

```
<name>/
  Dockerfile.debian-13   # build environment (apt dependencies only)
  env.sh                 # build image (-b) and/or start interactive container
  build.sh               # download, verify, extract, configure, compile, install, package
  checksums-sha256.txt   # sha256sum of the downloaded source tarball(s)
  .gitignore             # ignore tarballs and extracted source dirs
```

Some packages have extras (`patches/*.patch`, a wrapper script). Older packages may
have a `Dockerfile.ubuntu-noble` too; new packages only get `Dockerfile.debian-13`.

### Dockerfile.debian-13

The header is identical in every package — copy it verbatim (including the typo
"priviledged"):

```dockerfile
FROM debian:13

# apply latest security patches
RUN apt-get update \
 && apt-get -y upgrade \
 && apt-get -y full-upgrade \
 && apt-get -y autoremove \
 && apt-get -y clean

# basic tools
RUN apt-get -y install git sudo vim wget

# add non priviledged user for building
RUN useradd --uid 1000 --comment "Build" --shell /bin/bash --create-home build \
 && echo "build ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/build-nopasswd

# basic build environment
RUN apt-get -y install build-essential cmake

# <group> library            <- optional groups, e.g. "# SDL2 library", "# FFmpeg library"
RUN apt-get -y install ...

# other dependencies
RUN apt-get -y install \
  pkg-a \
  pkg-b

USER build
WORKDIR /build
```

- "basic build environment" holds the build system tools: `build-essential` plus
  `cmake` / `meson` / `ninja-build` / `pkgconf` as needed (prefer `pkgconf` over `pkg-config`).
- One `RUN` per logical group, each with a `# comment` header.
- Packages within a group are **sorted alphabetically**, one per line, 2-space indent,
  ` \` continuation.
- Extra basic tools (e.g. `unzip`, `xz-utils`) go on the "basic tools" line.

### env.sh

Identical everywhere except `TAG=<name>-build` (lowercase). Copy from another package
and change only the tag; keep it executable.

### build.sh

`#!/bin/sh`, `set -e`, variables at the top, short lowercase `# step` comments:

```sh
#!/bin/sh
set -e

NAME=luanti
VERSION=5.15.1
ARCH=$(uname -m)

# download sources
test -e ${NAME}-${VERSION}.tar.gz || \
  wget "https://github.com/<org>/${NAME}/archive/refs/tags/${VERSION}.tar.gz" \
    -O ${NAME}-${VERSION}.tar.gz

# check integrity
sha256sum -c checksums-sha256.txt

# clean up previous build
rm -rf ${NAME}-${VERSION}

# extract tarball
tar xzf ${NAME}-${VERSION}.tar.gz

# configure
mkdir -p "${NAME}-${VERSION}/build"
cd "${NAME}-${VERSION}/build"
cmake --install-prefix=/opt/<name> -DCMAKE_BUILD_TYPE=Release ..

# compile
make -j $(nproc)

# install
sudo make install

# create binary package
( cd /; tar cvzf "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" opt/<name> )
mv "/tmp/${NAME}-${VERSION}-${ARCH}.tar.gz" ../../
```

Conventions:
- Install prefix is always `/opt/<name>`; installing uses `sudo`.
- The binary package is `${NAME}-${VERSION}-${ARCH}.tar.gz` and contains `opt/<name>`,
  created from `/` and moved back into the package directory (adjust `../` depth to
  how deep the script `cd`'d).
- Sources are downloaded once (`test -e ... ||`) and always verified with `sha256sum -c`.
- Every build starts clean (`rm -rf` of the source dir, then extract again).
- Bundled extra libraries go in their own block separated by `# --------`, with their
  own `*_VERSION` variable (see `UZDoom/build.sh`).
- **Git clone variant** (when the release tarball lacks submodules; see `ppsspp/`,
  `dolphin/`): clone `--depth 1 --branch <tag> --recurse-submodules`, create
  `${NAME}-${VERSION}-git.tar.gz` and write its checksum; on later runs extract that
  tarball instead. In that case `checksums-sha256.txt` is in `.gitignore`.

### checksums-sha256.txt and .gitignore

```sh
sha256sum <name>-<version>.tar.gz > checksums-sha256.txt   # standard sha256sum format
printf '<name>-*.tar.gz\n<name>-*/\n' > .gitignore
```

## Minimal dependencies: the iterative workflow

The user wants an **absolute minimum** dependency list, found empirically:

1. Start with the header and only `build-essential cmake` (or meson etc.).
2. Run the build, read the **first** error, add exactly the package that fixes it
   (to "other dependencies" or a matching group), rebuild the image, try again.
3. Don't add things preemptively from upstream docs or CI dependency lists — these
   are usually much longer than needed. Use them only to look up package names.
4. Debian installs Recommends (none of the Dockerfiles use `--no-install-recommends`,
   except `dillo-wayland`), so one package sometimes covers the next error too
   (e.g. `autoconf` pulls `automake`). Check before adding.

To avoid rebuilding everything on every iteration, run only the failing step inside
the container against the already extracted source tree instead of the full
`build.sh` (which `rm -rf`'s the tree). Many upstream dependency scripts cache per
library (e.g. vpinball's `external.sh` uses `cache.txt`). Finish with a full,
clean `build.sh` run whenever time permits.

### Optional features need a deliberate choice

"It compiles" is not enough when a library silently drops optional backends.
**SDL** in particular builds fine without audio or KMSDRM, which makes the result
useless on a Pi. Check the configure summary (SDL3: "Enabled backends") and put the
chosen backends in their own commented group, e.g.:

```dockerfile
# SDL3 backends: Wayland, KMSDRM, OpenGL ES, udev, ALSA, PulseAudio and PipeWire
RUN apt-get -y install \
  libasound2-dev \
  libdrm-dev \
  libegl-dev \
  libgbm-dev \
  libpipewire-0.3-dev \
  libpulse-dev \
  libudev-dev \
  libwayland-dev \
  libxkbcommon-dev
```

## User preferences for SBC builds

- **OpenGL ES** on Raspberry Pi / SBCs. Prefer the GLES renderer/backend over desktop
  GL (e.g. vpinball: `-DRENDERER=GL -DBUILD_RPI=ON` on aarch64 gives `gles2.c` and
  `__OPENGLES__`). Verify it (compile defines in `flags.make`, version string, `readelf -d`).
- **Wayland, avoid X11.** Don't add `libx11-dev`/`libx*-dev` for X11 support. Note:
  Debian's `libegl-dev` depends on `libx11-dev`, which is unavoidable; check that the
  library still leaves X11 support off (SDL3 does: it needs more X extensions).
- **KMSDRM** (fullscreen without a desktop) is useful too; it needs `libdrm-dev`,
  `libgbm-dev`, `libegl-dev`, and `libudev-dev` for input (SDL3 doesn't scan
  `/dev/input` without udev).
- **Audio: PulseAudio and PipeWire** (plus ALSA).

## Test-building for arm64 on an x86_64 host

The real target is aarch64 (`ARCH=$(uname -m)`), and some builds behave differently
on x86_64 (e.g. desktop GL instead of GLES). If the host has qemu binfmt
(`ls /proc/sys/fs/binfmt_misc/qemu-aarch64`), build and test under emulation with a
separate tag, so you don't touch the user's own `<name>-build` image:

```sh
docker build --platform linux/arm64 -t <name>-build-arm64 -f Dockerfile.debian-13 .
docker run --rm --platform linux/arm64 \
  --mount "type=bind,src=$(pwd),dst=/build" <name>-build-arm64 bash -c "<cmd>"
```

`scripts/iterate.sh` in this skill does both in one go and writes the output to a log.

Caveats:
- Emulation is slow (roughly 5–10×). A large project with many dependencies
  (vpinball) takes hours. Run builds in the background, log to a file, and watch
  for errors and the container stopping.
- **`sudo` doesn't work under qemu-user** when the binfmt registration lacks the `C`
  flag (`flags: POF`): "effective uid is not 0". Run only the install/package step with
  `--user root` for testing. This only affects the test setup, not a real Pi.
- If upstream publishes an official aarch64 binary, compare the file list of the
  package with it (`tar tzf ... | sort | diff`).

## Commits

Conventional style, English, lowercase scope = package name:

- `feat(<name>): new package`
- `feat(<name>): bump to v<version>`
- `fix(<name>): <short description>`
- `chore: <repo-wide change>`

Only commit/push when the user asks.
