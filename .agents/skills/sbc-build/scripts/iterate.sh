#!/bin/bash
# Rebuild a package's Docker image for arm64 (qemu) and run a command inside it.
#
# usage: iterate.sh <package-dir> <logfile> <command...>
# example: iterate.sh vpinball /tmp/run1.log ./build.sh
set -e

PKG_DIR=$(realpath "$1")
LOG=$2
shift 2

TAG=$(basename "${PKG_DIR}" | tr '[:upper:]' '[:lower:]')-build-arm64

cd "${PKG_DIR}"

docker build --platform linux/arm64 -t "${TAG}" -f Dockerfile.debian-13 . > "${LOG}" 2>&1 \
  || { echo "image build failed, see ${LOG}"; exit 1; }

set +e
docker run --rm --platform linux/arm64 \
  --mount "type=bind,src=${PKG_DIR},dst=/build" \
  "${TAG}" bash -c "$*" >> "${LOG}" 2>&1
echo "exit=$?"
