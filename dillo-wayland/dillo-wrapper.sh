#!/bin/sh
export LD_LIBRARY_PATH=/opt/dillo-wayland/lib
exec /opt/dillo-wayland/bin/dillo.real "$@"
