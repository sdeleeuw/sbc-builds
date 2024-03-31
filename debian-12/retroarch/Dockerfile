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
RUN apt install -y build-essential pkg-config

# SDL2 library
RUN apt install -y libsdl2-dev

# FFmpeg library
RUN apt install -y libavcodec-dev libavdevice-dev libavfilter-dev libavformat-dev \
      libavutil-dev libpostproc-dev libswresample-dev libswscale-dev

# other retroarch dependencies
RUN apt install -y libfontconfig-dev libfreetype-dev libx11-xcb-dev wayland-protocols

USER build
WORKDIR /build
