#!/bin/sh

if [ "$1" = "-b" ]; then
  docker build -t retroarch-build .
fi

docker run \
  --interactive \
  --tty \
  --rm \
  --mount "type=bind,src=$(pwd),dst=/build" \
  retroarch-build
