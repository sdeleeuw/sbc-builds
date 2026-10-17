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
system libraries, four static bundled libs, `sed` fix for an upstream bug), `vkQuake/`
(meson, build-only Vulkan SDK parts, manual install, `patchelf`), `retroarch/`
(autodetecting `configure`, backends chosen in the Dockerfile, GLES without X11),
`supertuxkart/` (release tarball with game data, GLES + Vulkan, Debian libraries
instead of in-tree copies, removing in-tree libs from the package, menu entry `sed`).

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
- **Download URLs must keep working for this exact version.** Use a versioned URL
  (GitHub tag archive or release asset); avoid `latest/` directories and mirrors that
  drop old releases (eduke32 now uses `synthesis/${VERSION}/`; thextech moved from
  wohlsoft.ru to the GitHub release asset). When upstream publishes a checksum
  (GitHub asset `digest`, mesa release notes on docs.mesa3d.org), compare it before
  writing `checksums-sha256.txt`. Docs and wikis often link to unversioned files that
  upstream overwrites (thextech's game assets on wohlsoft.ru); list the release
  assets (`gh api repos/<org>/<repo>/releases/tags/<tag> --jq '.assets[] | "\(.name)
  \(.digest)"'`) for a versioned copy before using such a link.
- Every build starts clean (`rm -rf` of the source dir, then extract again).
- **No upstream install rules** (vkQuake, vpinball): install by hand with
  `sudo mkdir -p /opt/<name>/bin` and `sudo cp`, then package as usual.
- **Data packages** (game assets etc.) are shipped inside `opt/<name>` too. When
  upstream offers several variants (`.7z`, `.deb`), compare the contents before
  choosing: thextech's SMBX `.deb` holds the same assets as the `.7z` plus a launcher,
  menu entry and icon. Extract a `.deb` with `dpkg-deb -x` (no extra build
  dependency), copy its `usr/share` to `/opt/<name>/share` (keeps upstream's layout,
  e.g. `share/games/TheXTech/smbx13`) and `sed` the `/usr` paths in its scripts and
  menu entries (see `thextech/build.sh`). Only the checksum goes into the repo; add
  the file type to `.gitignore`.
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
- **Libraries built from the source tree can install into the package.**
  supertuxkart's in-tree angelscript and wiiuse put `lib/*.a`, headers and CMake files
  into `/opt/<name>`. Check the top level of the package
  (`tar tzf <package> | awk -F/ '{print $3}' | sort -u`) and `sudo rm -rf` what is
  only needed for linking, right after installing.
- **Build-only tools and link-only libraries** go into `/usr/local` too and are never
  shipped. vkQuake needs a newer Vulkan SDK than Debian: SPIRV-Tools (`spirv-opt`) only
  runs during the build, the Vulkan-Loader is only linked against, and at runtime the
  same soname (`libvulkan.so.1`) resolves to Debian's loader. Take all Khronos parts
  from one `vulkan-sdk-<version>` tag, the one upstream CI uses.
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

### Debian packages instead of in-tree copies

Many projects ship libraries in their source tree (`lib/`, `third_party/`) but use the
system copy when it's found (`USE_SYSTEM_*` options, or `find_library` before falling
back to `add_subdirectory`). **Prefer the Debian package** (the user's rule):
supertuxkart uses Debian's mcpp and squish; the configure log shows which one was
picked ("Use system libsquish" / "System libmcpp not found, use the bundled one").
Keep the in-tree copy when Debian doesn't have the library (angelscript, wiiuse), or
when the system copy costs a feature: supertuxkart only uses the system enet with
IPv6 turned off, so its patched copy stays.

**Check what an optional library is for** before leaving it out (or adding it):
grep the sources for its `ENABLE_*`/`HAVE_*` define. astcenc only gave a configure
warning, and turned out to be used only by supertuxkart's Vulkan renderer. Leaving it
out was right while Vulkan was disabled, but it was needed once Vulkan was turned on:
SBC GPUs (V3D, Adreno) don't support BC/S3TC under Vulkan, so ASTC is the only
compressed texture format they can use there.

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
appear. **There should be no RUNPATH** pointing to the build host:
- Meson adds the dir of a pkg-config library outside the system dirs (vkQuake:
  `/usr/local/lib` for the link-only Vulkan-Loader); remove it with
  `sudo patchelf --remove-rpath` after installing.
- Upstream may hardcode one (thextech: `set(CMAKE_INSTALL_RPATH ".")` loads libraries
  from the current directory); clear it with a `sed` after extracting.

For the test container, install only runtime packages, derived from the `NEEDED`
list. The package names don't follow the soname (`libastcenc.so.5d` →
`libastcenc5d`, plus the `t64` suffixes: `libcurl4t64`, `libpng16-16t64`,
`libssl3t64`); look them up with `apt-cache search` first, because one wrong name
makes `apt-get install` fail for all of them. GL via glvnd: `libGL.so.1` → `libgl1`, `libOpenGL.so.0` → `libopengl0`,
`libGLESv2.so.2` → `libgles2`. SDL's `dummy` video driver has no OpenGL, so "unable to
create window / OpenGL not available" after the startup messages is expected; it
still proves the binary loads its libraries and config. Some programs can list their
compiled-in drivers (`retroarch --features`), which beats grepping configure output.

When the program only loads its data **after** creating the window (thextech finds
its asset packs only then), `dummy` stops too early. Use SDL's `offscreen` driver
with Mesa's software renderer (llvmpipe) instead; that gets through window creation
and shows the data loading with `--verbose` or in the log:

```sh
apt-get install libegl1 libgl1-mesa-dri    # test container only
SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy timeout 15 /opt/<name>/bin/<binary> ...
```

This also proves the **OpenGL ES** context works, under qemu too: add `libgles2`
(and `libegl-mesa0`) and look for the GL version in the log (supertuxkart: "Using
renderer: OpenGL ES 3.2", then it compiles its shaders). Programs that load GL
through SDL/EGL (glad) don't list `libGLESv2` in `NEEDED`, so `readelf -d` can't show it.

SDL2's `offscreen` driver has **no Vulkan** support. To test a Vulkan renderer, use
Xvfb with Mesa's software Vulkan driver (lavapipe), in the test container only:

```sh
apt-get install libvulkan1 mesa-vulkan-drivers xvfb xauth
SDL_AUDIODRIVER=dummy timeout 60 xvfb-run -s '-screen 0 1280x720x24' \
  /opt/supertuxkart/bin/supertuxkart --render-driver=vulkan
```

The log should show the Vulkan device ("Vulkan renderer: llvmpipe"). SDL loads
`libvulkan.so.1` itself, so it's not in `NEEDED` either. This also works under qemu.

Run the program as a normal user (`useradd -m u; su - u -c "..."`), not as root,
and check where it writes its user data. thextech has an upstream bug: when
`~/.local/share` doesn't exist yet, it writes to `~/.local/` instead of
`~/.local/share/TheXTech/`, so create `~/.local/share` first to test the normal case.
`su -` gives a login `PATH` without `/opt/<name>/bin`, which is also how a menu
entry starts the program.

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
- **Menu entries with full paths.** The user adds the `.desktop` files from
  `/opt/<name>/share/applications` to the menu on the SBC, and `/opt/<name>/bin` is
  not in `PATH`. `sed` every `Exec=` line (including `[Desktop Action]` entries) to
  `/opt/<name>/bin/<binary>` and `Icon=` to the full path of the largest PNG; do the
  same for launcher scripts that call the binary. Upstream entries can be wrong (the
  SMBX `.deb` used `@F` instead of `%F`); check them with `desktop-file-validate` in
  the test container (`desktop-file-utils`; the deprecated `Encoding` key is only a
  warning).

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

Before reaching for qemu, try to **reproduce the aarch64 configuration on x86_64**
with explicit options. thextech's `TargetArch.cmake` reports `arm64` on aarch64,
which matches `arm.*` and disables desktop GL; building on x86_64 with
`-DTHEXTECH_BUILD_GL_DESKTOP_MODERN=OFF -DTHEXTECH_BUILD_GL_DESKTOP_LEGACY=OFF`
compiled the GLES-only path in minutes (it links `libGLESv2.so.2` instead of
`libGL.so.1`). Use a separate build dir for this check.

Otherwise, say in the summary that the package was only built on x86_64. When a qemu
build is needed, still iterate on x86_64 first and run qemu only once that succeeds;
only iterate under qemu when the x86_64 build can't tell you anything.

Check that the host has qemu binfmt (`cat /proc/sys/fs/binfmt_misc/qemu-aarch64`).
The registration doesn't survive a reboot and the host has no qemu-user packages;
register it with `docker run --privileged --rm tonistiigi/binfmt --install arm64`
(flags `POCF`, so `sudo` works) and remove the `tonistiigi/binfmt` image afterwards.
Build and test under emulation with a separate tag, so you don't touch the user's
own `<name>-build` image:

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
- A background task is stopped after 2 hours (supertuxkart took ~2¾ hours under
  qemu). For long builds, start a detached container right away instead of
  `scripts/iterate.sh`:
  `docker run -d --name <name>-arm64 --platform linux/arm64 --mount ... <name>-build-arm64 ./build.sh`,
  follow it with `docker logs -f <name>-arm64` and wait with
  `docker wait <name>-arm64` (prints the exit code), then `docker rm` it. If a
  foreground `docker run` gets stopped anyway, only the client dies and the container
  keeps building; find it with `docker ps`.
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

## Bumping a version

1. Diff the build files between the old and new release (`CMakeLists.txt`,
   `meson.build`, `configure` options): new minimum versions, renamed or removed
   options, new optional backends (vkQuake 1.37 prefers SDL3 when found; the existing
   SDL2 choice was kept with `-Duse_sdl3=disabled`).
2. Compare new minimum versions with Debian 13 (`docker run --rm debian:13 bash -c
   "apt-get update -qq && apt-cache policy <pkg>"`, plus trixie-backports). Upstream
   CI files (e.g. an AppImage Dockerfile) show the SDK/library versions upstream
   tests with.
3. Check every patch and `sed` still applies and is still needed
   (`patch -p1 --dry-run`). Drop it when upstream fixed the problem
   (Commander-Genius 3.6 no longer needs the GCC 14 `TTF_Font` patch).
4. Version schemes can change (TheXTech 1.3.7.x was followed by 1.7.4).
5. Older packages may lack `ARCH`, install and package steps, or still use an Ubuntu
   Dockerfile. Bump first and mention it; modernise only when the user agrees
   (retroarch moved to Debian 13 that way, thextech got its binary package).

## Checking for new versions

When asked for an overview, compare each `VERSION=` (and bundled `*_VERSION=`) with
upstream: GitHub `releases/latest` for most packages, tags for dolphin (no releases)
and munt (`libmt32emu_*`), the newest pre-release for vpinball, the GitLab API for
Commander-Genius, `archive.mesa3d.org`, `dillo-browser.org/release/`, and
dukeworld's `synthesis/latest/` for eduke32. Mark bundled libraries that are
deliberately pinned to the version upstream tests with (dosbox-staging's vcpkg
baseline, vkQuake's Vulkan SDK) as pinned, not as outdated.

## Host resources

The build host has 2 cores and a small disk (38 GB). Run one build at a time. After
finishing a package, remove its test image, the extracted source/build dirs and the
build cache (`docker builder prune -af`; the user agreed). Keep the downloaded
tarballs, and never touch images of other projects on the host.

## Commits

Conventional style, English, lowercase scope = package name:

- `feat(<name>): new package`
- `feat(<name>): bump to v<version>`
- `fix(<name>): <short description>`
- `chore: <repo-wide change>` (removing a package: `chore: remove <name>`)

**One commit per package**, also when removing several packages. `git rm` stages
right away, so another package's deletion can slip into the next commit: check
`git show --stat` before pushing. Git has no identity configured on the build host;
commit with `git -c user.name="Sander de Leeuw" -c user.email="s.deleeuw@gmail.com"`
(as in the history) instead of changing the config.

Only commit/push when the user asks. The user prefers no PR: work on a local branch,
rebase on `origin/main`, fast-forward `main` and push:

```sh
git fetch origin
git -c user.name="Sander de Leeuw" -c user.email="s.deleeuw@gmail.com" rebase origin/main
git -C /home/sander/Projects/sbc-builds merge --ff-only <branch>   # main is checked out there
git -C /home/sander/Projects/sbc-builds push origin main
```

`rebase` needs the identity too (it rewrites the commits). After a long build,
`origin/main` may have new conventions (menu entries with full paths arrived during
the supertuxkart build): read `git diff HEAD origin/main` of this skill and of
other packages, and apply them to the new package before committing.
