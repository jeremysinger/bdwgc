#!/bin/bash
# vim: expandtab sts=0 sw=4 smarttab
set -e

ROOT_DIR=$(pwd)/..

# arg-1 : Root directory
# arg-2 : cmake toolchain file
function build_boehmGC()
{
    ARCH=$(echo ${2} | cut -d '.' -f 1)
    SRC_DIR=${1}/build # build/source directory name used for all repos
    BUILD_DIR=${1}/bdwgc-build
    INSTALL_DIR=${1}/install
    BUILD_OPTS="-DCMAKE_BUILD_TYPE=Debug \
                -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
                -Denable_gcj_support=OFF \
                -Denable_parallel_mark=OFF \
                -Denable_threads=OFF \
                -Denable_dynamic_loading=OFF"


    mkdir -p ${BUILD_DIR}
    cmake -B ${BUILD_DIR} -S ${SRC_DIR} ${BUILD_OPTS} -DCMAKE_TOOLCHAIN_FILE=${2}
    cmake --build ${BUILD_DIR}
}


build_boehmGC ${ROOT_DIR} riscv64-purecap.cmake

# Clean up build directories
rm -rf ${ROOT_DIR}/bdwgc-build
