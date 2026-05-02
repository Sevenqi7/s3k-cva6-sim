#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
BUILD_DIR=builddir_verilator_cheshire

docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT_DIR:/workspace" -w /workspace/s3k/projects/hello \
  hakarlsson/riscv-picolibc /bin/sh -lc "
    if [ ! -d ${BUILD_DIR} ]; then
      meson setup ${BUILD_DIR} --cross-file=../../cross/rv64imac.ini -Dplatform=cheshire -Dcspad=0
    fi
    meson configure ${BUILD_DIR} -Dplatform=cheshire -Dcspad=0
    ninja -C ${BUILD_DIR}
  "
