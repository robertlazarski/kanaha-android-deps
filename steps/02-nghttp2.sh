#!/bin/bash
# nghttp2: the HTTP/2 framing library mod_http2 and Axis2/C's h2 sender use.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

fetch "nghttp2-$NGHTTP2_VERSION.tar.gz" "$NGHTTP2_URL" "$NGHTTP2_SHA256"
unpack "nghttp2-$NGHTTP2_VERSION.tar.gz" "nghttp2-$NGHTTP2_VERSION"
cd "$WORK/nghttp2-$NGHTTP2_VERSION"

log "nghttp2 $NGHTTP2_VERSION"
CFLAGS="-g -O2 $MAP_FLAGS" CXXFLAGS="-g -O2 $MAP_FLAGS" \
./configure --host=$TARGET --prefix="$DEPS" --disable-shared --enable-static \
    --disable-python-bindings --disable-examples --disable-app --enable-lib-only
make -j"$JOBS"
make install
require_arm64 "$DEPS/lib/libnghttp2.a"
require_no_build_paths "$DEPS/lib/libnghttp2.a"
