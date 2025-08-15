#!/bin/bash

TAG=vkquake-build

if [ "$1" = "-b" ]; then
  DISTRO=${2:-debian-13}
  DOCKERFILE=Dockerfile.${DISTRO}

  if [ -e ${DOCKERFILE} ]; then
    echo docker build --tag ${TAG} --file ${DOCKERFILE} .
    docker build -t ${TAG} -f ${DOCKERFILE} .
  else
    echo "${DOCKERFILE} not found."
    exit 1
  fi
fi

docker run \
  --interactive \
  --tty \
  --rm \
  --mount "type=bind,src=$(pwd),dst=/build" \
  ${TAG}
