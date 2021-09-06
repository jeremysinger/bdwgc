#!/bin/bash
# vim: expandtab sts=0 sw=4 smarttab
set -e

# arg-1 : Root directory
# arg-2 : cmake toolchain file
function build_bdwgc()
{
    ARCH=$(echo ${2} | cut -d '.' -f 1)
    SRC_DIR=${1}
    BUILD_DIR=${SRC_DIR}/bdwgc_build
    INSTALL_DIR=${SRC_DIR}/bdwgc_install
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


build_bdwgc $(pwd) riscv64-purecap.cmake

# Clean up build directories
rm -rf $(pwd)/bdwgc_build $(pwd)/bdwgc_install
