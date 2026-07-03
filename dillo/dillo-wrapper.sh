#!/bin/sh
export LD_LIBRARY_PATH=/opt/dillo/lib
exec /opt/dillo/bin/dillo.real "$@"
