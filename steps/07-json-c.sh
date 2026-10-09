#!/bin/bash
# json-c: the parser behind Axis2/C's JSON-RPC message receiver.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

fetch "json-c-$JSONC_VERSION.tar.gz" "$JSONC_URL" "$JSONC_SHA256"
unpack "json-c-$JSONC_VERSION.tar.gz" "json-c-json-c-$JSONC_VERSION"
cd "$WORK/json-c-json-c-$JSONC_VERSION"

log "json-c $JSONC_VERSION"
mkdir build && cd build
cmake \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-"$API" \
    -DCMAKE_INSTALL_PREFIX="$DEPS" \
    -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_APPS=OFF \
    ..
make -j"$JOBS"
make install
require_arm64 "$DEPS/lib/libjson-c.a"
