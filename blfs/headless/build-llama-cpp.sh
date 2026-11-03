#!/bin/sh
set -eu

# Build a caller-supplied, reviewed llama.cpp checkout. No network fetches and
# no implicit tracking of upstream main are performed by this recipe.
if [ "$#" -lt 1 ] || [ ! -f "$1/CMakeLists.txt" ]; then
    echo "Usage: $0 /path/to/llama.cpp [additional cmake arguments...]" >&2
    exit 2
fi

SOURCE_DIR=$(CDPATH= cd -- "$1" && pwd)
shift
PREFIX=\${PREFIX:-/opt/ginger/llama.cpp}
BUILD_DIR=\${BUILD_DIR:-/tmp/ginger-llama-cpp-build}

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DGGML_NATIVE=OFF \
    -DGGML_CUDA=OFF \
    "$@"
cmake --build "$BUILD_DIR" --parallel
cmake --install "$BUILD_DIR"

if [ ! -x "$PREFIX/bin/llama-server" ]; then
    echo "Build completed but $PREFIX/bin/llama-server was not installed." >&2
    exit 1
fi
printf 'llama.cpp installed to %s\n' "$PREFIX"
