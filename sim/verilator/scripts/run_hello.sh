#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SIM_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

"$SIM_DIR/scripts/build_hello.sh"
make -C "$SIM_DIR"
make -C "$SIM_DIR" run
