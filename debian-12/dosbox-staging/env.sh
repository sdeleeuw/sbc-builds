#!/bin/sh

if [ "$1" = "-b" ]; then
  docker build -t dosbox-staging-build .
fi

docker run \
  --interactive \
  --tty \
  --rm \
  --mount "type=bind,src=$(pwd),dst=/build" \
  dosbox-staging-build
