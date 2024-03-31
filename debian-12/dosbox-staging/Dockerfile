FROM debian:12

# apply latest security patches
RUN apt update \
 && apt -y upgrade \
 && apt -y full-upgrade \
 && apt -y autoremove \
 && apt -y clean

# basic tools
RUN apt install -y sudo tmux vim wget

# add non priviledged user for building
RUN useradd --uid 1000 --comment "Build" --shell /bin/bash --create-home build \
 && echo "build ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/build-nopasswd

# basic build environment
RUN apt install -y build-essential ccache cmake meson pkg-config

# SDL2 library
RUN apt install -y libsdl2-dev libsdl2-net-dev

# other dosbox-staging dependencies
RUN apt install -y \
      libatomic1 libfluidsynth-dev libopusfile-dev libpng-dev \
      libslirp-dev libspeexdsp-dev libxi-dev

USER build
WORKDIR /build
