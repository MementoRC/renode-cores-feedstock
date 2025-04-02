#!/usr/bin/env bash

set -o xtrace -o nounset -o pipefail -o errexit

# Update CMakeLists.txt and copy license files
cp "cmake-renode-infrastructure/src/Emulator/Cores/CMakeLists.txt" "${SRC_DIR}/src/Infrastructure/src/Emulator/Cores/CMakeLists.txt"

cp cmake-tlib/CMakeLists.txt "${SRC_DIR}/src/Infrastructure/src/Emulator/Cores/tlib"
cp cmake-tlib/tcg/CMakeLists.txt "${SRC_DIR}/src/Infrastructure/src/Emulator/Cores/tlib/tcg"

cp cmake-tlib/LICENSE "${RECIPE_DIR}/tlib-LICENSE"
cp "${SRC_DIR}/src/Infrastructure/src/Emulator/Cores/tlib/softfloat-3/COPYING.txt" "${RECIPE_DIR}/softfloat-3-COPYING.txt"

export CFLAGS="${CFLAGS} -Wno-unknown-warning-option"
export CFLAGS="${CFLAGS} -I${SRC_DIR}/src/Infrastructure/src/Emulator/Cores/tlib/tcg"
export CXXFLAGS="${CXXFLAGS} -Wno-unknown-warning-option"

if [[ "${target_platform}" == "linux-aarch64" ]]; then
    export CMAKE_ARGS="-DHOST_ARCH=aarch64 ${CMAKE_ARGS}"
fi
if [[ "${target_platform}" == "osx-arm64" ]]; then
    export CMAKE_ARGS="-DCMAKE_OSX_ARCHITECTURES=arm64 ${CMAKE_ARGS}"
    export CMAKE_ARGS="-DHOST_ARCH=aarch64 ${CMAKE_ARGS}"
fi

# Check weak implementations
pushd "${SRC_DIR}/tools/building" > /dev/null
  ./check_weak_implementations.sh
popd > /dev/null

export CORES_PATH=${SRC_DIR}/src/Infrastructure/src/Emulator/Cores
CORES=(
  "arm.le"
  "arm.be"
  "arm-m.le"
  "arm-m.be"
  "arm64.le"
  "ppc.le"
  "ppc.be"
  "ppc64.le"
  "ppc64.be"
  "i386.le"
  "x86_64.le"
  "riscv.le"
  "riscv64.le"
  "sparc.le"
  "sparc.be"
  "xtensa.le"
)

for core_config in "${CORES[@]}"; do
    CORE="${core_config%%.*}"
    ENDIAN="${core_config##*.}"
    BITS=32
    if [[ "$CORE" == *"64"* ]]; then
        BITS=64
    fi

    export EXTRA_CMAKE_ARGS=""
    if [[ "$ENDIAN" == "be" ]]; then
        export EXTRA_CMAKE_ARGS="-DTARGET_BIG_ENDIAN=1"
    fi

    CORE_DIR="$CORES_PATH/obj/Release/$CORE/$ENDIAN"
    mkdir -p "$CORE_DIR"
    pushd "$CORE_DIR" > /dev/null
        cmake -GNinja \
            -DTARGET_ARCH="${CORE}" \
            -DTARGET_WORD_SIZE="${BITS}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_VERBOSE_MAKEFILE=ON \
            ${EXTRA_CMAKE_ARGS} \
            ${CMAKE_ARGS} \
            ${CORES_PATH}

        cmake --build .
        mkdir -p "$CORES_PATH/bin/Release/lib"
        cp -u -v tlib/*.so "$CORES_PATH/bin/Release/lib/"
    popd > /dev/null
done

# Install to conda path
mkdir -p "${PREFIX}/lib/${PKG_NAME}"
tar -c -C "${CORES_PATH}/bin/Release/lib" . | tar -x -C "${PREFIX}/lib/${PKG_NAME}"

exit 0
