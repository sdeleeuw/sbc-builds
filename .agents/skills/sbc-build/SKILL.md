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
`vpinball/` (upstream external-deps script, GLES), `dosbox-staging/` (CMake preset with
system libraries, four static bundled libs, `sed` fix for an upstream bug).

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
  own `*_VERSION` variable (see `UZDoom/build.sh`). With several bundled libs, put all
  downloads before the single `sha256sum -c`, so every tarball is verified (see
  `dosbox-staging/build.sh`).
- Prefer building bundled libraries **static**: `-DBUILD_SHARED_LIBS=OFF` (or the
  project's own switch) plus `-DCMAKE_POSITION_INDEPENDENT_CODE=ON` (required: Debian's
  gcc builds PIE executables by default). Install them with `sudo` into `/usr/local`;
  the package then only contains `opt/<name>`. Disable optional features of a bundled
  lib that the program doesn't use and that would pull in more dependencies (e.g.
  FluidSynth as synthesizer only, without audio drivers). The alternative is shipping
  the `.so` inside `opt/<name>` (see `UZDoom/`).
- Upstream bugs in the build files get a small `sed` in `build.sh` right after
  extracting, with a comment explaining it and a link to the upstream issue/PR. Use
  `patches/*.patch` only for larger changes.
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
4. **Be explicit:** list every package the build directly needs, even when another
   listed package already pulls it in through Depends/Recommends (e.g. keep
   `libsdl2-dev` next to `libsdl2-image-dev`, keep `pkgconf` although SDL2_image pulls
   it in). "Minimal" means no package without a proven need, not leaving out direct
   dependencies.

**Fast iteration loop.** Rebuilding the image for every error is slow. Instead, keep
one container running and install packages into it as root, then rerun only the
failing step (not the full `build.sh`, which `rm -rf`'s the tree):

```sh
docker run -d --name <name>-iter --mount "type=bind,src=$(pwd),dst=/build" <image> sleep infinity
docker exec -u root <name>-iter apt-get -y install <pkg>
docker exec <name>-iter bash -c "cd <src> && <failing step>"
docker rm -f <name>-iter
```

Write down every package as you go, then move the list into the Dockerfile.
Many upstream dependency scripts cache per library (e.g. vpinball's `external.sh` uses
`cache.txt`).

**Always finish with a full, clean `build.sh` run in a fresh image** built from the
final Dockerfile. A package that was installed temporarily during iteration (or
later removed again) pulls in its own `-dev` dependencies and can hide a missing
package; only a fresh image proves the list is complete.

**Don't edit `build.sh` while it is running** (e.g. a background qemu build): `sh`
reads the script as it goes, so changes mid-run can break that run. Wait for the run
to finish, or prepare the change elsewhere.

### When a Debian package is not good enough

Debian having a package doesn't mean it's usable. You only find out when the build
gets that far:
- **Too old**: e.g. dosbox-staging 0.83 calls a FluidSynth 2.5 function, Debian 13
  has 2.4.
- **Broken**: e.g. Debian's `libiir-dev` CMake config refers to a static library the
  package doesn't ship, so `find_package(iir)` fails.

Such libraries are built in `build.sh` (static, see the build.sh conventions above).
Choosing a version: projects with a `vcpkg.json` record which versions they test
with. Look up `builtin-baseline` and read
`https://raw.githubusercontent.com/microsoft/vcpkg/<baseline>/ports/<port>/vcpkg.json`.
Take the newest patch release of that minor version.

Check the configure log for **downloads during the build**. Release tarballs without
submodules sometimes make CMake fetch the missing parts itself (FluidSynth fetches
`gcem`). That's acceptable when the URL and hash are pinned (`EXPECTED_HASH`);
otherwise switch to the git clone variant.

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

### Test the installed package, not only the build

A successful build and a created tarball don't prove the package works. Upstream
install rules are often untested (dosbox-staging's CI only builds the vcpkg presets;
`cmake --install` put the resources one directory too deep, so the binary aborted on
startup because it couldn't find its shaders). In a fresh container:

```sh
sudo tar xzf <name>-<version>-<arch>.tar.gz -C /
/opt/<name>/bin/<binary> --version      # plus a command that loads resources,
                                        # e.g. dosbox --list-shaders
SDL_VIDEODRIVER=dummy timeout 5 /opt/<name>/bin/<binary> ...   # headless start
readelf -d /opt/<name>/bin/<binary> | grep -E "NEEDED|RUNPATH"
```

`readelf -d` should only list Debian runtime libraries; static bundled libs must not
appear.

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

The real target is aarch64 (`ARCH=$(uname -m)`), but **by default only build natively
on x86_64**, with a separate test tag (e.g. `<name>-build-test`). Use it to find the
dependencies, fix build errors and run the tests above; that takes minutes instead of
hours. The user builds the package on the target device itself afterwards, so a qemu
build usually only costs time.

**Don't run an arm64 build under qemu**, except in these two cases:

1. **The user asks for it** explicitly.
2. **The build differs on x86_64 in a way that matters**, so the x86_64 build can't
   verify the result. Example: vpinball only gets OpenGL ES with `-DBUILD_RPI=ON` on
   aarch64; the x86_64 build uses desktop GL, so the GLES path was never compiled.
   Look for options or backends that upstream only enables on aarch64/ARM
   (`CMAKE_SYSTEM_PROCESSOR` checks, RPI/GLES switches). Say in one line why the
   qemu build is needed before starting it.

Otherwise, say in the summary that the package was only built on x86_64. When a qemu
build is needed, still iterate on x86_64 first and run qemu only once that succeeds;
only iterate under qemu when the x86_64 build can't tell you anything.

If the host has qemu binfmt
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
  flag (`flags: POF`): "effective uid is not 0". Run as root (`--user root`); that's
  enough when only the install/package step needs `sudo`. If `build.sh` also uses `sudo`
  along the way (installing bundled libs), run the whole script as root and give the
  files back afterwards:
  `bash -c "./build.sh; rc=\$?; chown -R 1000:1000 /build; exit \$rc"`.
  `scripts/iterate.sh` runs as the build user, so use `docker run` directly in that
  case. This only affects the test setup, not a real Pi.
- If upstream publishes an official aarch64 binary, compare the file list of the
  package with it (`tar tzf ... | sort | diff`).

## Commits

Conventional style, English, lowercase scope = package name:

- `feat(<name>): new package`
- `feat(<name>): bump to v<version>`
- `fix(<name>): <short description>`
- `chore: <repo-wide change>`

Only commit/push when the user asks.
